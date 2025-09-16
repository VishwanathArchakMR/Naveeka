// C:\flutterapp\myapp\backend\controllers\favoritesController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const Favorite = require('../models/Favorite'); // { userId, entityType, entityId, tags[], createdAt, updatedAt }
const Place = require('../models/Place');
const Hotel = require('../models/Hotel');
const Restaurant = require('../models/Restaurant');
const Activity = require('../models/Activity');
const Airport = require('../models/Airport');
const TrainStation = require('../models/TrainStation');
const BusStop = require('../models/BusStop');
const Landmark = require('../models/Landmark');

// Services
const cacheService = require('../services/cacheService');       // optional Redis
const locationService = require('../services/locationService'); // haversine distance
const mapService = require('../services/mapService');           // geojson helpers

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const parseCSV = (v) => (v ? String(v).split(',').map((s) => s.trim()).filter(Boolean) : []);
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));

const ENTITY_MODELS = {
  place: Place,
  hotel: Hotel,
  restaurant: Restaurant,
  activity: Activity,
  airport: Airport,
  train_station: TrainStation,
  bus_stop: BusStop,
  landmark: Landmark
};

async function loadEntity(entityType, entityId) {
  const Model = ENTITY_MODELS[entityType];
  if (!Model) return null;
  return Model.findById(entityId)
    .select('name title city country address tz location rating reviews pricing currency tags category categories iata icao station_code stop_code')
    .lean();
}

function entityToFeature(doc, entityType) {
  const coords = doc?.location?.coordinates;
  if (!coords || !Array.isArray(coords) || coords.length < 2) return null;
  const [lng, lat] = coords;
  const base = {
    id: doc._id,
    type: entityType,
    name: doc.name || doc.title || entityType,
    city: doc.city || doc.address?.city || null,
    country: doc.country || doc.address?.country || null,
    tz: doc.tz || null,
    rating: doc.rating?.score || doc.reviews?.averageRating || null,
    reviews: doc.rating?.reviews || doc.reviews?.totalReviews || null,
    price: doc.pricing?.basePrice || null,
    currency: doc.currency || doc.pricing?.currency || null,
    tags: doc.tags || [],
    category: doc.category || doc.categories || null,
    geo: `geo:${lat},${lng}`
  };
  if (entityType === 'airport') {
    base.iata = doc.iata || null;
    base.icao = doc.icao || null;
  }
  if (entityType === 'train_station') base.station_code = doc.station_code || null;
  if (entityType === 'bus_stop') base.stop_code = doc.stop_code || null;

  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] },
    properties: base
  };
}

/**
 * GET /api/v1/favorites
 * Query: ?types=place,hotel&tags=beach,food&page=1&limit=24&sortBy=createdAt&sortOrder=desc&lat=&lng=
 */
exports.getFavorites = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const {
    types, // csv entity types
    tags,  // csv tags filter
    page = 1,
    limit = 24,
    sortBy = 'createdAt', // createdAt|name|rating|distance
    sortOrder = 'desc',
    lat,
    lng
  } = req.query;

  const typeArr = parseCSV(types);
  const tagArr = parseCSV(tags);

  const filter = { userId };
  if (typeArr.length) filter.entityType = { $in: typeArr };
  if (tagArr.length) filter.tags = { $in: tagArr };

  const p = clamp(parseInt(page || 1), 1, 200);
  const l = clamp(parseInt(limit || 24), 1, 100);
  const skip = (p - 1) * l;

  // Sort on favorite fields; name/rating/distance enrichment applied client-side or via later pass
  const sort = {};
  switch (sortBy) {
    case 'name':
      sort.createdAt = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'rating':
      sort.createdAt = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'distance':
      sort.createdAt = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'createdAt':
    default:
      sort.createdAt = sortOrder === 'asc' ? 1 : -1;
      break;
  }

  const [rows, total] = await Promise.all([
    Favorite.find(filter).sort(sort).skip(skip).limit(l).lean(),
    Favorite.countDocuments(filter)
  ]);

  // Hydrate entities and enrich with distance and geoUri
  const uLat = parseNum(lat);
  const uLng = parseNum(lng);

  const enriched = await Promise.all(
    rows.map(async (f) => {
      const doc = await loadEntity(f.entityType, f.entityId);
      const item = {
        id: f._id,
        entityType: f.entityType,
        entityId: f.entityId,
        tags: f.tags || [],
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
        entity: null
      };
      if (doc) {
        const coords = doc?.location?.coordinates;
        if (coords) {
          const [lngE, latE] = coords;
          item.entity = {
            name: doc.name || doc.title || f.entityType,
            city: doc.city || doc.address?.city || null,
            country: doc.country || doc.address?.country || null,
            rating: doc.rating?.score || doc.reviews?.averageRating || null,
            price: doc.pricing?.basePrice || null,
            currency: doc.currency || doc.pricing?.currency || null,
            geoUri: `geo:${latE},${lngE}`
          };
          if (uLat != null && uLng != null) {
            const distKm = locationService.calculateDistance(uLat, uLng, latE, lngE);
            item.distance = Math.round(distKm * 100) / 100;
            item.distanceUnit = 'km';
          }
        }
      }
      return item;
    })
  );

  const totalPages = Math.ceil(total / l);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Favorites fetched successfully', {
      favorites: enriched,
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

/**
 * POST /api/v1/favorites
 * Body: { entityType: 'place'|'hotel'|..., entityId, tags?:[] }
 * Idempotent add: returns existing favorite if already present
 */
exports.addFavorite = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { entityType, entityId, tags = [] } = req.body || {};
  if (!entityType || !entityId) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'entityType and entityId are required');
  }

  // Validate entity exists
  const doc = await loadEntity(entityType, entityId);
  if (!doc) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Target entity not found');
  }

  // Idempotent upsert
  const existing = await Favorite.findOne({ userId, entityType, entityId }).lean();
  if (existing) {
    return res.status(StatusCodes.OK).json(
      new ApiResponse(StatusCodes.OK, 'Already favorited', { id: existing._id, entityType, entityId, tags: existing.tags, createdAt: existing.createdAt, updatedAt: existing.updatedAt, generatedAt: toISO() })
    );
  }

  const favorite = await Favorite.create({ userId, entityType, entityId, tags });
  return res.status(StatusCodes.CREATED).json(
    new ApiResponse(StatusCodes.CREATED, 'Added to favorites', {
      id: favorite._id,
      entityType,
      entityId,
      tags,
      createdAt: favorite.createdAt,
      updatedAt: favorite.updatedAt,
      generatedAt: toISO()
    })
  );
});

/**
 * DELETE /api/v1/favorites/:id
 * Removes a favorite by its id
 */
exports.removeFavorite = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { id } = req.params;
  const fav = await Favorite.findOneAndDelete({ _id: id, userId }).lean();
  if (!fav) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Favorite not found');
  }

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Removed from favorites', { id, generatedAt: toISO() }));
});

/**
 * POST /api/v1/favorites/toggle
 * Body: { entityType, entityId, tags?:[] }
 * Toggles favorite state; returns { favorited: boolean, id? }
 */
exports.toggleFavorite = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { entityType, entityId, tags = [] } = req.body || {};
  if (!entityType || !entityId) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'entityType and entityId are required');
  }

  const existing = await Favorite.findOne({ userId, entityType, entityId }).lean();
  if (existing) {
    await Favorite.deleteOne({ _id: existing._id });
    return res
      .status(StatusCodes.OK)
      .json(new ApiResponse(StatusCodes.OK, 'Unfavorited', { favorited: false, id: existing._id, generatedAt: toISO() }));
  }

  // Validate entity exists before creating
  const doc = await loadEntity(entityType, entityId);
  if (!doc) throw new ApiError(StatusCodes.NOT_FOUND, 'Target entity not found');

  const favorite = await Favorite.create({ userId, entityType, entityId, tags });
  return res
    .status(StatusCodes.CREATED)
    .json(new ApiResponse(StatusCodes.CREATED, 'Favorited', { favorited: true, id: favorite._id, generatedAt: toISO() }));
});

/**
 * GET /api/v1/favorites/tags
 * Returns user tag facets with counts
 */
exports.getTags = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const cacheKey = `favorites:tags:${userId}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res
      .status(StatusCodes.OK)
      .json(new ApiResponse(StatusCodes.OK, 'Favorite tags fetched (cache)', cached));
  }

  const tags = await Favorite.aggregate([
    { $match: { userId } },
    { $unwind: { path: '$tags', preserveNullAndEmptyArrays: false } },
    { $group: { _id: '$tags', count: { $sum: 1 } } },
    { $sort: { count: -1, _id: 1 } },
    { $project: { _id: 0, tag: '$_id', count: 1 } }
  ]);

  const payload = { tags, generatedAt: toISO() };
  await cacheService?.set?.(cacheKey, payload, 1800);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Favorite tags fetched', payload));
});

/**
 * PUT /api/v1/favorites/:id/tags
 * Body: { tags: [] }
 * Replaces tags for a favorite
 */
exports.updateTags = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { id } = req.params;
  const { tags = [] } = req.body || {};

  const fav = await Favorite.findOneAndUpdate(
    { _id: id, userId },
    { $set: { tags, updatedAt: new Date() } },
    { new: true }
  ).lean();

  if (!fav) throw new ApiError(StatusCodes.NOT_FOUND, 'Favorite not found');

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Favorite tags updated', { id, tags: fav.tags, generatedAt: toISO() }));
});

/**
 * GET /api/v1/favorites/geojson
 * Query: ?types=place,hotel&tags=...&limit=1000
 * Returns RFC 7946 FeatureCollection for map view
 */
exports.getFavoritesGeoJSON = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { types, tags, limit = 1000 } = req.query;
  const typeArr = parseCSV(types);
  const tagArr = parseCSV(tags);

  const filter = { userId };
  if (typeArr.length) filter.entityType = { $in: typeArr };
  if (tagArr.length) filter.tags = { $in: tagArr };

  const rows = await Favorite.find(filter)
    .limit(clamp(parseInt(limit), 1, 5000))
    .select('entityType entityId')
    .lean();

  // Load entities per type in batches
  const byType = rows.reduce((acc, r) => {
    acc[r.entityType] = acc[r.entityType] || [];
    acc[r.entityType].push(r.entityId);
    return acc;
  }, {});

  const featureLists = await Promise.all(
    Object.entries(byType).map(async ([entityType, ids]) => {
      const Model = ENTITY_MODELS[entityType];
      if (!Model) return [];
      const docs = await Model.find({ _id: { $in: ids } })
        .select('name title city country address tz location rating reviews pricing currency tags category categories iata icao station_code stop_code')
        .lean();
      return docs
        .map((d) => entityToFeature(d, entityType))
        .filter(Boolean);
    })
  );

  const features = featureLists.flat();
  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };

  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});

/**
 * GET /api/v1/favorites/by-location?lat=&lng=&radius=&types=&limit=
 * Groups favorites within radius and returns sorted by distance
 */
exports.getFavoritesByLocation = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { lat, lng, radius = 50, types, limit = 200 } = req.query;
  if (lat == null || lng == null) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'lat and lng are required');
  }

  const typeArr = parseCSV(types);
  const filter = { userId };
  if (typeArr.length) filter.entityType = { $in: typeArr };

  const favs = await Favorite.find(filter)
    .limit(clamp(parseInt(limit), 1, 2000))
    .lean();

  const uLat = parseNum(lat);
  const uLng = parseNum(lng);
  const radKm = parseNum(radius);

  const within = [];
  for (const f of favs) {
    const doc = await loadEntity(f.entityType, f.entityId);
    const coords = doc?.location?.coordinates;
    if (!coords) continue;
    const [lngE, latE] = coords;
    const distKm = locationService.calculateDistance(uLat, uLng, latE, lngE);
    if (distKm <= radKm) {
      within.push({
        id: f._id,
        entityType: f.entityType,
        entityId: f.entityId,
        name: doc.name || doc.title || f.entityType,
        distance: Math.round(distKm * 100) / 100,
        distanceUnit: 'km',
        city: doc.city || doc.address?.city || null,
        country: doc.country || doc.address?.country || null,
        geoUri: `geo:${latE},${lngE}`,
        tags: f.tags || []
      });
    }
  }

  within.sort((a, b) => a.distance - b.distance);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Favorites grouped by location', {
      center: { lat: uLat, lng: uLng },
      radiusKm: radKm,
      items: within,
      totalFound: within.length,
      generatedAt: toISO()
    })
  );
});
