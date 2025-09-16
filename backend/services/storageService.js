// backend/services/storageService.js
// Centralized wrapper around Cloudinary for uploads, deletions, and signatures.
// Matches folder scoping used in routes/uploadRoutes.js

const cloudinary = require('cloudinary').v2;

// Read folder config similarly to uploadRoutes
const BASE_FOLDER = process.env.SOULTRAIL_MEDIA_FOLDER || 'soultrail';
const APPEND_ENV = (process.env.SOULTRAIL_MEDIA_APPEND_ENV || 'false') === 'true';
const EFFECTIVE_FOLDER = APPEND_ENV
  ? `${BASE_FOLDER}/${process.env.NODE_ENV || 'development'}`
  : BASE_FOLDER;

// Validate required env vars early (non-fatal here; routes may guard usage)
['CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET'].forEach((key) => {
  if (!process.env[key]) {
    console.error(`❌ Missing Cloudinary env var: ${key}`);
  }
});

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

/**
 * Convert a memory file buffer (from multer) to a data URI for Cloudinary.
 */
function fileToDataURI(file) {
  const base64 = Buffer.from(file.buffer).toString('base64');
  return `data:${file.mimetype};base64,${base64}`;
}

/**
 * Upload a single file buffer to Cloudinary.
 * Returns object with secure_url, public_id, resource_type, etc.
 */
async function uploadBuffer(file, { folder = EFFECTIVE_FOLDER, transformations = [] } = {}) {
  const dataURI = fileToDataURI(file);
  return cloudinary.uploader.upload(dataURI, {
    folder,
    resource_type: 'auto',
    transformation: transformations.length
      ? transformations
      : [
          { width: 1200, height: 800, crop: 'limit' },
          { quality: 'auto' }
        ]
  });
}

/**
 * Upload multiple files (array of multer files).
 * Returns an array of upload results.
 */
async function uploadBuffers(files, options = {}) {
  const results = [];
  for (const f of files) {
    // eslint-disable-next-line no-await-in-loop
    const r = await uploadBuffer(f, options);
    results.push(r);
  }
  return results;
}

/**
 * Verify a Cloudinary public_id is safely within our folder.
 */
function isScopedPublicId(publicId) {
  return typeof publicId === 'string' && publicId.startsWith(`${EFFECTIVE_FOLDER}/`);
}

/**
 * Delete a Cloudinary asset by public_id (scoped).
 * Attempts image first, then video.
 */
async function deletePublicId(publicId) {
  if (!isScopedPublicId(publicId)) {
    const err = new Error('Deletion not allowed outside scoped folder');
    err.statusCode = 403;
    throw err;
  }

  // Try image
  let result = await cloudinary.uploader.destroy(publicId, { resource_type: 'image' });

  if (result.result !== 'ok' && result.result !== 'not found') {
    // Try video
    result = await cloudinary.uploader.destroy(publicId, { resource_type: 'video' });
  }

  return result;
}

/**
 * Generate a signature for client-side direct uploads to the same folder.
 */
function generateSignature({ folder = EFFECTIVE_FOLDER, timestamp = Math.round(Date.now() / 1000) } = {}) {
  if (!process.env.CLOUDINARY_API_SECRET) {
    const err = new Error('Cloudinary secret not configured');
    err.statusCode = 500;
    throw err;
  }

  const signature = cloudinary.utils.api_sign_request(
    { timestamp, folder },
    process.env.CLOUDINARY_API_SECRET
  );

  return {
    timestamp,
    signature,
    api_key: process.env.CLOUDINARY_API_KEY,
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    folder
  };
}

module.exports = {
  EFFECTIVE_FOLDER,
  uploadBuffer,
  uploadBuffers,
  deletePublicId,
  generateSignature,
  isScopedPublicId
};

/*
Integration notes:
- You can swap uploadRoutes to call storageService.uploadBuffer / uploadBuffers / deletePublicId / generateSignature
  for centralized logic. Current routes already implement equivalent behavior, so switching is optional.
- Folder scoping prevents accidental deletion of assets outside your namespace.
- Environment vars:
  - CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET
  - SOULTRAIL_MEDIA_FOLDER (default "soultrail")
  - SOULTRAIL_MEDIA_APPEND_ENV=true|false
  - NODE_ENV (used when APPEND_ENV=true)
*/
