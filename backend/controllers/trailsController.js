// C:\flutterapp\myapp\backend\controllers\trailsController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const Trail = require('../models/Trail');
const Review = require('../models/Review');

// Services
const trailService = require('../services/trailService');           // elevation profile, path building, availability/conditions
const cacheService = require('../services/cacheService');           // optional Redis
const locationService = require('../services/locationService');     // haversine distance
const mapService = require('../services/mapService');               // GeoJSON helpers (LineString, FeatureCollection)

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601 UTC
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const parseCSV = (v) => (v ? String(v).split(',').map((s) => s.trim()).filter(Boolean) : []);
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));

function buildTrailFilter(q) {
  const {
    q: search,
    city,
    country,
    region,
    difficulty,         // csv: easy,moderate,hard,expert
    minLengthKm,
    maxLengthKm,
    minElevGainM,
    maxElevGainM,
    types,              // csv: hike,run,mtb,cycle,walk,trek
    tags,               // csv
    lat,
    lng,
    radius = 0,
    openNow             // optional boolean flag if service populates window
  } = q;

  const filter = { isActive: { $ne: false } };

  if (search) {
    filter.$or = [
      { name: new RegExp(search, 'i') },
      { city: new RegExp(search, 'i') },
      { country: new RegExp(search, 'i') },
      { region: new RegExp(search, 'i') },
      { tags: new RegExp(search, 'i') }
    ];
  }

  if (city) filter.city = new RegExp(city, 'i');
  if (country) filter.country = new RegExp(country, 'i');
  if (region) filter.region = new RegExp(region, 'i');

  if (difficulty) {
    const arr = parseCSV(difficulty);
    if (arr.length) filter.difficulty = { $in: arr };
  }

  if (types) {
    const arr = parseCSV(types);
    if (arr.length) filter.types = { $in: arr };
  }

  if (tags) {
    const arr = parseCSV(tags);
    if (arr.length) filter.tags = { $in: arr };
  }

  if (minLengthKm || maxLengthKm) {
    filter.length_km = {};
    if (minLengthKm) filter.length_km.$gte = Number(minLengthKm);
    if (maxLengthKm) filter.length_km.$lte = Number(maxLengthKm);
  }

  if (minElevGainM || maxElevGainM) {
    filter.elev_gain_m = {};
    if (minElevGainM) filter.elev_gain_m.$gte = Number(minElevGainM);
    if (maxElevGainM) filter.elev_gain_m.$lte = Number(maxElevGainM);
  }

  if (openNow === 'true') filter.openNow = true;

  if (lat && lng && !Number.isNaN(parseFloat(lat)) && !Number.isNaN(parseFloat(lng)) && Number(radius) > 0) {
    filter.location = {
      $near: {
        $geometry: { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
        $maxDistance: Number(radius) * 1000
      }
    };
  }

  return filter;
}

// GET /api/v1/trails
// Query: pagination, filters, sorting, optional distance enrichment
exports.getTrails = asyncHandler(async (req, res) => {
  const {
    page = 1,
    limit = 24,
    sortBy = 'popularity', // length|difficulty|rating|distance|elevation|createdAt|popularity
    sortOrder = 'desc',
    lat,
    lng
  } = req.query;

  const filter = buildTrailFilter(req.query);

  const sort = {};
  switch (sortBy) {
    case 'length':
      sort.length_km = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'difficulty':
      sort.difficulty_index = sortOrder === 'asc' ? 1 : -1; // assume precomputed
      break;
    case 'elevation':
      sort.elev_gain_m = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'rating':
      sort['reviews.averageRating'] = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'distance':
      sort.popularity = -1; // $near sorts by distance if geo used
      break;
    case 'createdAt':
      sort.createdAt = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'popularity':
    default:
      sort.popularity = -1;
      sort.viewCount = -1;
      sort.createdAt = -1;
  }

  const p = clamp(parseInt(page), 1, 200);
  const l = clamp(parseInt(limit), 1, 100);
  const skip = (p - 1) * l;

  const [rows, total] = await Promise.all([
    Trail.find(filter)
      .sort(sort)
      .skip(skip)
      .limit(l)
      .select('name city country region tz location types tags photos length_km elev_gain_m elev_loss_m max_alt_m min_alt_m loop difficulty difficulty_index waypoints_count reviews popularity viewCount openNow createdAt updatedAt')
      .lean(),
    Trail.countDocuments(filter)
  ]);

  const uLat = parseNum(lat);
  const uLng = parseNum(lng);

  const items = rows.map((t) => {
    const out = { ...t };
    if (t?.location?.coordinates) {
      const [lngT, latT] = t.location.coordinates;
      out.geoUri = `geo:${latT},${lngT}`;
      if (uLat != null && uLng != null) {
        const distKm = locationService.calculateDistance(uLat, uLng, latT, lngT);
        out.distance = Math.round(distKm * 100) / 100;
        out.distanceUnit = 'km';
      }
    }
    return out;
  });

  const totalPages = Math.ceil(total / l);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Trails fetched successfully', {
      trails: items,
      pagination: {
        currentPage: p,
        totalPages,
        totalCount: total,
        limit: l,
        hasNextPage: p < totalPages,
        hasPrevPage: p > 1
      },
      generatedAt: toISO()
    })
  );
});

// GET /api/v1/trails/nearby?lat=&lng=&radius=&limit=&difficulty=
exports.getNearbyTrails = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 25, limit = 24, difficulty } = req.query;
  if (!lat || !lng) throw new ApiError(StatusCodes.BAD_REQUEST, 'Latitude and longitude are required');

  const cacheKey = `nearby_trails:${lat}:${lng}:${radius}:${limit}:${difficulty || 'all'}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Nearby trails fetched (cache)', cached));
  }

  const filter = buildTrailFilter({ lat, lng, radius, difficulty });
  const rows = await Trail.find(filter)
    .limit(clamp(parseInt(limit), 1, 100))
    .select('name city country location length_km elev_gain_m difficulty loop reviews')
    .lean();

  const enriched = rows.map((t) => {
    const [lngT, latT] = t.location.coordinates;
    const distKm = locationService.calculateDistance(parseFloat(lat), parseFloat(lng), latT, lngT);
    return {
      ...t,
      distance: Math.round(distKm * 100) / 100,
      distanceUnit: 'km',
      geoUri: `geo:${latT},${lngT}`
    };
  });

  const payload = {
    trails: enriched,
    center: { lat: parseFloat(lat), lng: parseFloat(lng) },
    radiusKm: Number(radius),
    totalFound: enriched.length,
    generatedAt: toISO()
  };

  await cacheService?.set?.(cacheKey, payload, 600);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Nearby trails fetched', payload));
});

// GET /api/v1/trails/suggest?q=&limit=
exports.suggestTrails = asyncHandler(async (req, res) => {
  const { q = '', limit = 8 } = req.query;
  if (!q || String(q).trim().length < 2) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: [] }));
  }

  const lmt = Math.min(parseInt(limit), 20);

  const suggestions = await Trail.find({
    $or: [{ name: new RegExp(q, 'i') }, { city: new RegExp(q, 'i') }, { country: new RegExp(q, 'i') }, { tags: new RegExp(q, 'i') }]
  })
    .limit(lmt)
    .sort({ popularity: -1, viewCount: -1 })
    .select('name city country location length_km difficulty')
    .lean();

  const mapped = suggestions.map((t) => {
    const [lngT, latT] = t?.location?.coordinates || [null, null];
    return {
      id: t._id,
      name: t.name,
      city: t.city || null,
      country: t.country || null,
      length_km: t.length_km || null,
      difficulty: t.difficulty || null,
      geoUri: latT && lngT ? `geo:${latT},${lngT}` : null
    };
  });

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: mapped }));
});

// GET /api/v1/trails/:id
exports.getTrailById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { userLat, userLng, includeReviews = 'true', includeProfile = 'true' } = req.query;

  const trail = await Trail.findById(id)
    .select('-__v')
    .lean();

  if (!trail) throw new ApiError(StatusCodes.NOT_FOUND, 'Trail not found');

  if (trail?.location?.coordinates) {
    const [lngT, latT] = trail.location.coordinates;
    trail.geoUri = `geo:${latT},${lngT}`;
    if (userLat && userLng) {
      const distKm = locationService.calculateDistance(parseFloat(userLat), parseFloat(userLng), latT, lngT);
      trail.distance = Math.round(distKm * 100) / 100;
      trail.distanceUnit = 'km';
    }
  }

  if (includeProfile === 'true') {
    const profile = await trailService.getElevationProfile(id).catch(() => null);
    trail.elevationProfile = profile || null;
  }

  if (includeReviews === 'true') {
    const reviews = await Review.find({ trailId: id, isActive: true })
      .populate('userId', 'name avatar')
      .sort({ createdAt: -1 })
      .limit(10)
      .lean();
    trail.recentReviews = reviews;
  }

  await Trail.findByIdAndUpdate(id, { $inc: { viewCount: 1 } }).catch(() => {});

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Trail fetched', trail));
});

// GET /api/v1/trails/:id/path
// Returns RFC 7946 FeatureCollection with LineString/MultiLineString plus key waypoints
exports.getTrailPath = asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Prefer precomputed GeoJSON on the model; fallback to service builder
  const trail = await Trail.findById(id).select('name path_geojson waypoints location').lean();
  if (!trail) throw new ApiError(StatusCodes.NOT_FOUND, 'Trail not found');

  let line = null;
  if (trail?.path_geojson?.type && (trail.path_geojson.type === 'LineString' || trail.path_geojson.type === 'MultiLineString')) {
    line = trail.path_geojson; // already RFC 7946 [lng,lat]
  } else {
    line = await trailService.buildPathGeoJSON(id); // {type, coordinates}
  }

  const features = [];

  if (line) {
    features.push({
      type: 'Feature',
      geometry: line,
      properties: { kind: 'trail_path', trailId: id, name: trail.name }
    });
  }

  // Add start/end/waypoints as Point features
  if (Array.isArray(trail?.waypoints)) {
    for (const w of trail.waypoints) {
      if (w?.coordinates && Array.isArray(w.coordinates) && w.coordinates.length >= 2) {
        features.push({
          type: 'Feature',
          geometry: { type: 'Point', coordinates: w.coordinates }, // [lng,lat]
          properties: {
            kind: 'waypoint',
            name: w.name || null,
            type: w.type || null,
            geo: `geo:${w.coordinates},${w.coordinates}`
          }
        });
      }
    }
  }

  // Add main location point if present
  if (trail?.location?.coordinates) {
    features.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: trail.location.coordinates },
      properties: {
        kind: 'trail_head',
        trailId: id,
        geo: `geo:${trail.location.coordinates},${trail.location.coordinates}`
      }
    });
  }

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json'); // RFC 7946 media type
  return res.status(StatusCodes.OK).json(fc);
});

// POST /api/v1/trails/:id/reviews
// Body: { rating, title, comment, photos[] }
exports.addReview = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { rating, title, comment, photos = [] } = req.body || {};
  if (!rating) throw new ApiError(StatusCodes.BAD_REQUEST, 'rating is required');

  const review = await Review.create({
    userId: req.user?.id,
    trailId: id,
    type: 'trail',
    rating: parseFloat(rating),
    title,
    comment,
    photos
  });

  await trailService.updateTrailRating(id).catch(() => {});

  const populated = await Review.findById(review._id).populate('userId', 'name avatar').lean();
  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Review added', populated));
});

// GET /api/v1/trails/trending?region=&limit=
exports.getTrending = asyncHandler(async (req, res) => {
  const { region, limit = 10 } = req.query;

  const cacheKey = `trails:trending:${region || 'all'}:${limit}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Trending trails fetched (cache)', cached));
  }

  const match = { isActive: { $ne: false } };
  if (region) match.region = new RegExp(region, 'i');

  const rows = await Trail.aggregate([
    { $match: match },
    {
      $addFields: {
        trendingScore: {
          $add: [
            { $multiply: ['$completionCount', 0.45] },
            { $multiply: ['$viewCount', 0.2] },
            { $multiply: ['$reviews.totalReviews', 0.25] },
            { $multiply: ['$reviews.averageRating', 0.1] }
          ]
        }
      }
    },
    { $sort: { trendingScore: -1 } },
    { $limit: Math.min(parseInt(limit), 50) },
    {
      $project: {
        name: 1,
        region: 1,
        city: 1,
        country: 1,
        photos: { $slice: ['$photos', 3] },
        length_km: 1,
        elev_gain_m: 1,
        difficulty: 1,
        'reviews.averageRating': 1,
        'reviews.totalReviews': 1,
        trendingScore: 1
      }
    }
  ]);

  const payload = { trails: rows, generatedAt: toISO() };
  await cacheService?.set?.(cacheKey, payload, 1800);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Trending trails fetched', payload));
});

// GET /api/v1/trails/geojson?lat=&lng=&radius=&region=&limit=
exports.getTrailsGeoJSON = asyncHandler(async (req, res) => {
  const filter = buildTrailFilter(req.query);
  const { limit = 2000 } = req.query;

  const rows = await Trail.find(filter)
    .limit(Math.min(parseInt(limit), 5000))
    .select('name city country region tz location length_km elev_gain_m difficulty reviews')
    .lean();

  const features = rows
    .filter((t) => t?.location?.coordinates && Array.isArray(t.location.coordinates))
    .map((t) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: t.location.coordinates }, // [lng,lat]
      properties: {
        id: t._id,
        type: 'trail',
        name: t.name,
        city: t.city || null,
        country: t.country || null,
        region: t.region || null,
        tz: t.tz || null,
        length_km: t.length_km || null,
        elev_gain_m: t.elev_gain_m || null,
        difficulty: t.difficulty || null,
        rating: t.reviews?.averageRating || null,
        geo: `geo:${t.location.coordinates},${t.location.coordinates}`
      }
    }));

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});
