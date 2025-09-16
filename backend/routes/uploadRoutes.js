// backend/routes/uploadRoutes.js
const express = require('express');
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const { protect, partnerOrAdmin } = require('../middleware/auth');

const router = express.Router();

// Compute the base folder for assets
// Defaults to "soultrail", and can append NODE_ENV if desired.
const BASE_FOLDER = process.env.SOULTRAIL_MEDIA_FOLDER || 'soultrail';
const APPEND_ENV = (process.env.SOULTRAIL_MEDIA_APPEND_ENV || 'false') === 'true';
const EFFECTIVE_FOLDER = APPEND_ENV
  ? `${BASE_FOLDER}/${process.env.NODE_ENV || 'development'}`
  : BASE_FOLDER;

// Validate required env vars early (uploads may be disabled at server level)
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

// Multer memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/')) {
      return cb(null, true);
    }
    cb(new Error('Only image and video files are allowed'), false);
  }
});

// Helper: standard error response
const sendError = (res, status, message, errors) => {
  return res.status(status).json({ success: false, message, ...(errors && { errors }) });
};

// Helper: upload buffer to Cloudinary
const uploadToCloudinary = async (file, folder = EFFECTIVE_FOLDER) => {
  const base64 = Buffer.from(file.buffer).toString('base64');
  const dataURI = `data:${file.mimetype};base64,${base64}`;
  return cloudinary.uploader.upload(dataURI, {
    folder,
    resource_type: 'auto',
    transformation: [
      { width: 1200, height: 800, crop: 'limit' },
      { quality: 'auto' }
    ]
  });
};

// Ensure a given publicId is inside our allowed folder namespace
const isScopedPublicId = (publicId) => {
  // Cloudinary public_id typically includes the folder prefix (e.g., "soultrail/.../assetname")
  // Only allow delete if it starts with EFFECTIVE_FOLDER + "/"
  return typeof publicId === 'string' && publicId.startsWith(`${EFFECTIVE_FOLDER}/`);
};

// Upload single file
// POST /api/upload/single
// Private (Partner/Admin)
router.post('/single', protect, partnerOrAdmin, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return sendError(res, 400, 'No file uploaded');

    const result = await uploadToCloudinary(req.file, EFFECTIVE_FOLDER);

    res.json({
      success: true,
      message: 'File uploaded successfully',
      data: {
        url: result.secure_url,
        public_id: result.public_id,
        filename: req.file.originalname,
        size: req.file.size,
        type: req.file.mimetype,
        resource_type: result.resource_type,
        folder: EFFECTIVE_FOLDER
      }
    });
  } catch (error) {
    console.error('Upload error:', error);
    return sendError(res, 500, 'Upload failed');
  }
});

// Upload multiple files (max 10)
// POST /api/upload/multiple
// Private (Partner/Admin)
router.post('/multiple', protect, partnerOrAdmin, upload.array('files', 10), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) return sendError(res, 400, 'No files uploaded');

    const uploads = req.files.map(async (file) => {
      const result = await uploadToCloudinary(file, EFFECTIVE_FOLDER);
      return {
        url: result.secure_url,
        public_id: result.public_id,
        filename: file.originalname,
        size: file.size,
        type: file.mimetype,
        resource_type: result.resource_type,
        folder: EFFECTIVE_FOLDER
      };
    });

    const results = await Promise.all(uploads);

    res.json({
      success: true,
      message: 'Files uploaded successfully',
      data: results
    });
  } catch (error) {
    console.error('Multiple upload error:', error);
    return sendError(res, 500, 'Upload failed');
  }
});

// Delete file from Cloudinary
// DELETE /api/upload/:publicId
// Private (Partner/Admin)
router.delete('/:publicId', protect, partnerOrAdmin, async (req, res) => {
  try {
    const { publicId } = req.params;
    if (!publicId) return sendError(res, 400, 'publicId is required');

    // Safety: ensure this publicId is inside our allowed folder
    if (!isScopedPublicId(publicId)) {
      return sendError(res, 403, 'Deletion not allowed outside scoped folder');
    }

    // Attempt to delete as image first, then as video if needed
    let result = await cloudinary.uploader.destroy(publicId, { resource_type: 'image' });

    // Cloudinary returns { result: 'not found' } if resource doesn't exist
    if (result.result !== 'ok' && result.result !== 'not found') {
      result = await cloudinary.uploader.destroy(publicId, { resource_type: 'video' });
    }

    if (result.result === 'ok' || result.result === 'not found') {
      return res.json({
        success: true,
        message: 'File deleted (or not found)',
        data: { result: result.result }
      });
    }

    return sendError(res, 400, 'Failed to delete file');
  } catch (error) {
    console.error('Delete file error:', error);
    return sendError(res, 500, 'Delete failed');
  }
});

// Get upload signature for client-side direct uploads
// GET /api/upload/signature
// Private (Partner/Admin)
router.get('/signature', protect, partnerOrAdmin, async (req, res) => {
  try {
    if (!process.env.CLOUDINARY_API_SECRET) {
      return sendError(res, 500, 'Cloudinary secret not configured');
    }

    const timestamp = Math.round(Date.now() / 1000);
    const paramsToSign = { timestamp, folder: EFFECTIVE_FOLDER };

    const signature = cloudinary.utils.api_sign_request(
      paramsToSign,
      process.env.CLOUDINARY_API_SECRET
    );

    res.json({
      success: true,
      data: {
        timestamp,
        signature,
        api_key: process.env.CLOUDINARY_API_KEY,
        cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
        folder: EFFECTIVE_FOLDER
      }
    });
  } catch (error) {
    console.error('Get signature error:', error);
    return sendError(res, 500, 'Failed to generate signature');
  }
});

module.exports = router;

/*
APIs touched here:
- POST /api/upload/single             (partner/admin)
- POST /api/upload/multiple           (partner/admin)
- DELETE /api/upload/:publicId        (partner/admin; scoped to EFFECTIVE_FOLDER)
- GET /api/upload/signature           (partner/admin; signed params with EFFECTIVE_FOLDER)

MongoDB integration:
- None directly (Cloudinary-backed storage).

Environment variables used here:
- CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET
- SOULTRAIL_MEDIA_FOLDER (default "soultrail")
- SOULTRAIL_MEDIA_APPEND_ENV=true|false (default false)
- NODE_ENV (used when SOULTRAIL_MEDIA_APPEND_ENV=true → folder becomes "<SOULTRAIL_MEDIA_FOLDER>/<NODE_ENV>")

Notes:
- Deletion is scoped so only assets within the configured folder can be removed.
- Signature endpoint also pins uploads to the same folder for client-side direct uploads.
- Server may optionally disable all uploads via ENABLE_UPLOADS=false at the application bootstrap.
*/
