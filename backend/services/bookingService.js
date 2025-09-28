// backend/services/bookingService.js

const LocationMaster = require('../models/LocationMaster');

/**
 * Convert kilometers to meters for MongoDB $geoNear/$near distances.
 */
function kmToMeters(km) {
  const v = Number.isFinite(km) ? km : 0;
  return Math.max(0, v) * 1000;
}

/**
 * Basic lat/lng validation.
 */
function validateCoords({ lng, lat }) {
  if (
    typeof lng !== 'number' ||
    typeof lat !== 'number' ||
    lng < -180 ||
    lng > 180 ||
    lat < -90 ||
    lat > 90
  ) {
    throw new Error('Invalid coordinates. Expect lng in [-180,180], lat in [-90,90].');
  }
}

/**
 * Normalize limit/skip bounds.
 */
function normalizePaging(limit, skip) {
  const lim = Math.min(200, Math.max(1, Number(limit) || 50));
  const sk = Math.max(0, Number(skip) || 0);
  return { lim, sk };
}

/**
 * Nearby search using $geoNear (requires a 2dsphere index on `location` and must be the first pipeline stage).
 * Returns documents with `distanceMeters` and `distanceKm` fields for convenience.
 *
 * @param {Object} opts
 * @param {number} opts.lng - longitude (GeoJSON first)
 * @param {number} opts.lat - latitude
 * @param {number} [opts.radiusKm=5] - search radius in kilometers
 * @param {Object} [opts.filter={}] - additional filters (e.g., { category: 'Cafe', isApproved: true })
 * @param {number} [opts.limit=50] - max docs
 * @param {number} [opts.skip=0] - offset
 * @param {Object} [opts.project=null] - projection map
 */
async function findNearbyLocations({
  lng,
  lat,
  radiusKm = 5,
  filter = {},
  limit = 50,
  skip = 0,
  project = null,
}) {
  validateCoords({ lng, lat });
  const { lim, sk } = normalizePaging(limit, skip);

  const maxDistance = kmToMeters(radiusKm);

  // $geoNear must be the first stage in the pipeline and uses [lng, lat] GeoJSON order.
  // Spherical true uses Earth-like geometry on 2dsphere index. [web:6979][web:6995][web:6993]
  const pipeline = [
    {
      $geoNear: {
        near: { type: 'Point', coordinates: [lng, lat] },
        distanceField: 'distanceMeters',
        maxDistance,
        query: {
          isActive: true,
          isApproved: true,
          ...filter,
        },
        spherical: true,
      },
    },
    { $sort: { distanceMeters: 1 } },
    { $skip: sk },
    { $limit: lim },
    {
      $addFields: { distanceKm: { $divide: ['$distanceMeters', 1000] } },
    },
  ];

  if (project && typeof project === 'object') {
    pipeline.push({ $project: project });
  }

  const results = await LocationMaster.aggregate(pipeline).allowDiskUse(true);
  return results;
}

/**
 * Full-text search using the collection's single text index (see model definition).
 * If you need both relevance and distance, run textSearch first and then issue a separate nearby call or vice versa.
 *
 * @param {Object} opts
 * @param {string} opts.q - search query
 * @param {Object} [opts.filter={}] - additional filters
 * @param {number} [opts.limit=50]
 * @param {number} [opts.skip=0]
 * @param {Object} [opts.project=null]
 */
async function textSearchLocations({ q, filter = {}, limit = 50, skip = 0, project = null }) {
  const { lim, sk } = normalizePaging(limit, skip);
  const text = (q || '').toString().trim();

  if (!text) {
    // No query: simple find with basic filters
    return await LocationMaster.find({ isActive: true, isApproved: true, ...filter }, project)
      .skip(sk)
      .limit(lim)
      .lean();
  }

  // Uses the single text index configured with weights in the model.
  // Sorting by textScore ranks documents by relevance. [web:6998]
  return await LocationMaster.find(
    { $text: { $search: text }, isActive: true, isApproved: true, ...filter },
    { score: { $meta: 'textScore' }, ...(project || {}) }
  )
    .sort({ score: { $meta: 'textScore' } })
    .skip(sk)
    .limit(lim)
    .lean();
}

/**
 * Facade to unify booking location search based on a UI selection from the app.
 * Pass a resolved lat/lng and radiusKm; the service handles unit conversion if needed.
 *
 * @param {Object} opts
 * @param {'nearMe'|'address'|'mapPin'} opts.mode
 * @param {number} [opts.lat]
 * @param {number} [opts.lng]
 * @param {number} [opts.radius]
 * @param {'metric'|'imperial'} [opts.unit='metric']
 * @param {Object} [opts.filter]
 * @param {number} [opts.limit]
 * @param {number} [opts.skip]
 */
async function searchBySelection({
  mode,
  lat,
  lng,
  radius,
  unit = 'metric',
  filter = {},
  limit,
  skip,
}) {
  if (!['nearMe', 'address', 'mapPin'].includes(mode)) {
    throw new Error('Invalid mode. Expected nearMe | address | mapPin');
  }

  // If unit is imperial, convert miles to km
  let radiusKm = Number(radius) || 5;
  if (unit === 'imperial') {
    radiusKm = radiusKm * 1.60934;
  }

  // For address mode, lat/lng should be resolved by the caller before invoking this function.
  if (typeof lat !== 'number' || typeof lng !== 'number') {
    throw new Error('lat/lng are required after address/map resolution');
  }

  return await findNearbyLocations({
    lng,
    lat,
    radiusKm,
    filter,
    limit,
    skip,
  });
}

module.exports = {
  kmToMeters,
  findNearbyLocations,
  textSearchLocations,
  searchBySelection,
};
