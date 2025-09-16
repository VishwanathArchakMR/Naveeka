// C:\flutterapp\myapp\backend\controllers\historyController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models (as defined in upgrade plan)
const History = require('../models/History');     // { userId, kind, entityType, entityId, action, startedAt, endedAt, location(Point), fromRef, toRef, distanceKm, fare, currency, metadata }
const Place = require('../models/Place');
const Hotel = require('../models/Hotel');
const Restaurant = require('../models/Restaurant');
const Activity = require('../models/Activity');
const Flight = require('../models/Flight');
const Train = require('../models/Train');
const Bus = require('../models/Bus');
const Cab = require('../models/Cab');
const Airport = require('../models/Airport');
const TrainStation = require('../models/TrainStation');
const BusStop = require('../models/BusStop');

// Services
const cacheService = require('../services/cacheService');           // optional Redis
const locationService = require('../services/locationService');     // distance calc
const mapService = require('../services/mapService');               // geojson helpers
const flightService = require('../services/flightService');         // rebook helpers
const trainService = require('../services/trainService');
const busService = require('../services/busService');
const cabService = require('../services/cabService');

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601 UTC
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const isStr = (s) => typeof s === 'string' && s.trim().length > 0;

const ENTITY_MODELS = {
  place: Place,
  hotel: Hotel,
  restaurant: Restaurant,
  activity: Activity,
  flight: Flight,
  train: Train,
  bus: Bus,
  cab: Cab,
  airport: Airport,
  train_station: TrainStation,
  bus_stop: BusStop
};

// Hydrate minimal card info for list/timeline
async function hydrateEntity(entityType, entityId) {
  const Model = ENTITY_MODELS[entityType];
  if (!Model) return null;
  const doc = await Model.findById(entityId)
    .select('name title iata icao station_code stop_code city country address location pricing currency duration rating reviews')
    .lean();
  if (!doc) return null;
  const coords = doc?.location?.coordinates;
  const entity = {
    id: doc._id,
    name: doc.name || doc.title || entityType,
    city: doc.city || doc.address?.city || null,
    country: doc.country || doc.address?.country || null,
    price: doc.pricing?.basePrice || null,
    currency: doc.currency || doc.pricing?.currency || null,
    duration: doc.duration || null,
    rating: doc.rating?.score || doc.reviews?.averageRating || null
  };
  if (coords) {
    const [lng, lat] = coords;
    entity.geoUri = `geo:${lat},${lng}`;
  }
  if (entityType === 'airport') {
    entity.iata = doc.iata || null;
    entity.icao = doc.icao || null;
  }
  if (entityType === 'train_station') entity.station_code = doc.station_code || null;
  if (entityType === 'bus_stop') entity.stop_code = doc.stop_code || null;
  return entity;
}

/**
 * GET /api/v1/history
 * Query: ?types=place,flight,bus&actions=visited,booked,completed&startDate&endDate&lat&lng&radius&page&limit&sortBy=date&sortOrder=desc
 */
exports.getHistory = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const {
    types,           // csv of entityType
    actions,         // csv of action
    startDate, endDate,
    lat, lng, radius,
    page = 1, limit = 25,
    sortBy = 'date', // date|distance|price
    sortOrder = 'desc'
  } = req.query;

  const typeArr = (types ? String(types).split(',') : []).filter(Boolean);
  const actionArr = (actions ? String(actions).split(',') : []).filter(Boolean);

  const filter = { userId };
  if (typeArr.length) filter.entityType = { $in: typeArr };
  if (actionArr.length) filter.action = { $in: actionArr };
  if (startDate || endDate) {
    filter.startedAt = {};
    if (startDate) filter.startedAt.$gte = new Date(startDate);
    if (endDate) filter.startedAt.$lte = new Date(endDate);
  }
  if (lat && lng && radius) {
    filter.location = {
      $near: {
        $geometry: { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
        $maxDistance: Number(radius) * 1000
      }
    };
  }

  const sort = {};
  switch (sortBy) {
    case 'distance':
      sort.distanceKm = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'price':
      sort.fare = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'date':
    default:
      sort.startedAt = sortOrder === 'asc' ? 1 : -1;
  }

  const p = clamp(parseInt(page || 1), 1, 200);
  const l = clamp(parseInt(limit || 25), 1, 100);
  const skip = (p - 1) * l;

  const [rows, total] = await Promise.all([
    History.find(filter).sort(sort).skip(skip).limit(l).lean(),
    History.countDocuments(filter)
  ]);

  // Enrich rows
  const uLat = parseNum(lat);
  const uLng = parseNum(lng);
  const items = await Promise.all(
    rows.map(async (h) => {
      const entity = await hydrateEntity(h.entityType, h.entityId);
      const out = {
        id: h._id,
        entityType: h.entityType,
        entityId: h.entityId,
        action: h.action,
        kind: h.kind || null,
        startedAt: h.startedAt,
        endedAt: h.endedAt,
        distanceKm: h.distanceKm || null,
        fare: h.fare || null,
        currency: h.currency || null,
        fromRef: h.fromRef || null,
        toRef: h.toRef || null,
        entity
      };
      if (h?.location?.coordinates) {
        const [lngH, latH] = h.location.coordinates;
        out.geoUri = `geo:${latH},${lngH}`;
        if (uLat != null && uLng != null) {
          const distKm = locationService.calculateDistance(uLat, uLng, latH, lngH);
          out.distanceFromUserKm = Math.round(distKm * 100) / 100;
        }
      }
      return out;
    })
  );

  const totalPages = Math.ceil(total / l);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'History fetched successfully', {
      history: items,
      pagination: { currentPage: p, totalPages, totalCount: total, limit: l, hasNextPage: p < totalPages, hasPrevPage: p > 1 },
      generatedAt: toISO()
    })
  );
});

/**
 * GET /api/v1/history/timeline
 * Groups by calendar day (local user TZ handled client-side) with lightweight card data
 */
exports.getTimeline = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { startDate, endDate, types, actions, limit = 500 } = req.query;
  const typeArr = (types ? String(types).split(',') : []).filter(Boolean);
  const actionArr = (actions ? String(actions).split(',') : []).filter(Boolean);

  const filter = { userId };
  if (typeArr.length) filter.entityType = { $in: typeArr };
  if (actionArr.length) filter.action = { $in: actionArr };
  if (startDate || endDate) {
    filter.startedAt = {};
    if (startDate) filter.startedAt.$gte = new Date(startDate);
    if (endDate) filter.startedAt.$lte = new Date(endDate);
  }

  const rows = await History.find(filter)
    .sort({ startedAt: -1 })
    .limit(clamp(parseInt(limit), 1, 2000))
    .lean();

  // Group by yyyy-mm-dd
  const groups = {};
  for (const h of rows) {
    const dayKey = new Date(h.startedAt).toISOString().slice(0, 10);
    groups[dayKey] = groups[dayKey] || [];
    const entity = await hydrateEntity(h.entityType, h.entityId);
    groups[dayKey].push({
      id: h._id,
      entityType: h.entityType,
      action: h.action,
      startedAt: h.startedAt,
      endedAt: h.endedAt,
      entity
    });
  }

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'History timeline fetched', {
      timeline: Object.entries(groups).map(([date, items]) => ({ date, items })),
      generatedAt: toISO()
    })
  );
});

/**
 * GET /api/v1/history/geojson
 * Map overlay of visited/booked items (Points + optional LineString routes)
 */
exports.getGeoJSON = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { startDate, endDate, types, actions, limit = 2000 } = req.query;
  const typeArr = (types ? String(types).split(',') : []).filter(Boolean);
  const actionArr = (actions ? String(actions).split(',') : []).filter(Boolean);

  const filter = { userId };
  if (typeArr.length) filter.entityType = { $in: typeArr };
  if (actionArr.length) filter.action = { $in: actionArr };
  if (startDate || endDate) {
    filter.startedAt = {};
    if (startDate) filter.startedAt.$gte = new Date(startDate);
    if (endDate) filter.startedAt.$lte = new Date(endDate);
  }

  const rows = await History.find(filter)
    .sort({ startedAt: -1 })
    .limit(clamp(parseInt(limit), 1, 5000))
    .lean();

  const features = [];

  for (const h of rows) {
    // Point feature for primary location
    if (h?.location?.coordinates) {
      features.push({
        type: 'Feature',
        geometry: { type: 'Point', coordinates: h.location.coordinates },
        properties: {
          id: h._id,
          entityType: h.entityType,
          action: h.action,
          startedAt: h.startedAt,
          endedAt: h.endedAt,
          geo: `geo:${h.location.coordinates},${h.location.coordinates}`
        }
      });
    }
    // Optional route geometry for transport (flight/train/bus/cab)
    if (Array.isArray(h?.route?.coordinates) && h.route.coordinates.length > 1) {
      features.push({
        type: 'Feature',
        geometry: { type: 'LineString', coordinates: h.route.coordinates },
        properties: {
          id: h._id,
          kind: 'route',
          entityType: h.entityType,
          distanceKm: h.distanceKm || null
        }
      });
    }
  }

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});

/**
 * GET /api/v1/history/stats
 * Returns totals for Travel Stats and expense tracker
 */
exports.getStats = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { startDate, endDate } = req.query;
  const filter = { userId };
  if (startDate || endDate) {
    filter.startedAt = {};
    if (startDate) filter.startedAt.$gte = new Date(startDate);
    if (endDate) filter.startedAt.$lte = new Date(endDate);
  }

  const rows = await History.find(filter).select('entityType distanceKm fare currency startedAt').lean();

  const totals = {
    distanceKm: 0,
    trips: 0,
    byMode: { flight: 0, train: 0, bus: 0, cab: 0 },
    spend: {}
  };

  for (const h of rows) {
    totals.trips += 1;
    if (h.distanceKm) totals.distanceKm += Number(h.distanceKm);
    if (totals.byMode[h.entityType] != null) totals.byMode[h.entityType] += 1;
    if (h.fare && h.currency) {
      totals.spend[h.currency] = (totals.spend[h.currency] || 0) + Number(h.fare);
    }
  }
  totals.distanceKm = Math.round(totals.distanceKm * 100) / 100;

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'History stats fetched', { totals, generatedAt: toISO() })
  );
});

/**
 * POST /api/v1/history
 * Body: { entityType, entityId, action, startedAt?, endedAt?, location?, fromRef?, toRef?, distanceKm?, fare?, currency?, route? }
 */
exports.addHistory = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const payload = req.body || {};
  if (!payload.entityType || !payload.entityId || !payload.action) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'entityType, entityId and action are required');
  }

  const rec = await History.create({
    userId,
    entityType: payload.entityType,
    entityId: payload.entityId,
    action: payload.action,
    kind: payload.kind || null,
    startedAt: payload.startedAt ? new Date(payload.startedAt) : new Date(),
    endedAt: payload.endedAt ? new Date(payload.endedAt) : null,
    location: payload.location || null,
    fromRef: payload.fromRef || null,
    toRef: payload.toRef || null,
    distanceKm: payload.distanceKm || null,
    fare: payload.fare || null,
    currency: payload.currency || null,
    route: payload.route || null,
    metadata: payload.metadata || {}
  });

  return res
    .status(StatusCodes.CREATED)
    .json(new ApiResponse(StatusCodes.CREATED, 'History item added', { id: rec._id, createdAt: rec.createdAt, generatedAt: toISO() }));
});

/**
 * DELETE /api/v1/history/:id
 */
exports.removeHistory = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { id } = req.params;
  const deleted = await History.findOneAndDelete({ _id: id, userId }).lean();
  if (!deleted) throw new ApiError(StatusCodes.NOT_FOUND, 'History item not found');

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'History item removed', { id, generatedAt: toISO() }));
});

/**
 * POST /api/v1/history/:id/rebook
 * For transport items: generates a new quote/search payload for quick rebooking
 */
exports.rebook = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { id } = req.params;
  const hist = await History.findOne({ _id: id, userId }).lean();
  if (!hist) throw new ApiError(StatusCodes.NOT_FOUND, 'History item not found');

  let payload = null;
  switch (hist.entityType) {
    case 'flight':
      payload = await flightService.quickRebook(hist); // returns { searchBody | quote }
      break;
    case 'train':
      payload = await trainService.quickRebook(hist);
      break;
    case 'bus':
      payload = await busService.quickRebook(hist);
      break;
    case 'cab':
      payload = await cabService.quickRebook(hist);
      break;
    default:
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Rebook not supported for this entity type');
  }

  if (!payload) throw new ApiError(StatusCodes.INTERNAL_SERVER_ERROR, 'Unable to generate rebook payload');

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Rebook payload generated', { payload, generatedAt: toISO() })
  );
});
