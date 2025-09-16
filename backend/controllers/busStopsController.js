// C:\flutterapp\myapp\backend\controllers\busStopsController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const BusStop = require('../models/BusStop');
const Bus = require('../models/Bus');

// Services
const cacheService = require('../services/cacheService');       // optional Redis
const locationService = require('../services/locationService'); // distance calc
const mapService = require('../services/mapService');           // geo helpers

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const parseCSV = (v) => (v ? String(v).split(',').map((s) => s.trim()).filter(Boolean) : []);
const isFiniteNumber = (n) => typeof n === 'number' && Number.isFinite(n);

// Build Mongo filter from query
function buildStopFilter(q) {
  const {
    q: search,
    city,
    country,
    tz,
    stop_code,
    hasStopCode,
    lat,
    lng,
    radius = 0
  } = q;

  const filter = { isActive: { $ne: false } };

  if (search) {
    filter.$or = [
      { name: new RegExp(search, 'i') },
      { city: new RegExp(search, 'i') },
      { country: new RegExp(search, 'i') },
      { stop_code: new RegExp(`^${search}$`, 'i') }
    ];
  }
  if (city) filter.city = new RegExp(city, 'i');
  if (country) filter.country = new RegExp(country, 'i');
  if (tz) filter.tz = new RegExp(tz, 'i');
  if (stop_code) filter.stop_code = new RegExp(`^${stop_code}$`, 'i');
  if (hasStopCode === 'true') filter.stop_code = { $exists: true, $ne: '' };

  if (lat && lng && parseFloat(lat) && parseFloat(lng) && Number(radius) > 0) {
    filter.location = {
      $near: {
        $geometry: { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
        $maxDistance: Number(radius) * 1000 // km -> m
      }
    };
  }

  return filter;
}

// GET /api/v1/bus-stops
// List stops with filters, pagination, sort, and distance enrichment
exports.getBusStops = asyncHandler(async (req, res) => {
  const {
    page = 1,
    limit = 25,
    sortBy = 'popularity', // name|country|distance|popularity
    sortOrder = 'desc',
    lat,
    lng
  } = req.query;

  const filter = buildStopFilter(req.query);

  const sort = {};
  switch (sortBy) {
    case 'name':
      sort.name = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'country':
      sort.country = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'distance':
      // when using $near, Mongo sorts by distance automatically; fallback
      sort.name = 1;
      break;
    case 'popularity':
    default:
      sort.popularity = -1;
      sort.viewCount = -1;
      sort.createdAt = -1;
      break;
  }

  const p = Math.max(parseInt(page), 1);
  const l = Math.min(Math.max(parseInt(limit), 1), 100);
  const skip = (p - 1) * l;

  const [rows, total] = await Promise.all([
    BusStop.find(filter)
      .sort(sort)
      .skip(skip)
      .limit(l)
      .select('name stop_code city country tz location amenities popularity viewCount createdAt updatedAt')
      .lean(),
    BusStop.countDocuments(filter)
  ]);

  const uLat = parseNum(lat);
  const uLng = parseNum(lng);

  const items = rows.map((s) => {
    const out = { ...s };
    if (s?.location?.coordinates) {
      const [lngS, latS] = s.location.coordinates;
      out.geoUri = `geo:${latS},${lngS}`;
      if (isFiniteNumber(uLat) && isFiniteNumber(uLng)) {
        const distKm = locationService.calculateDistance(uLat, uLng, latS, lngS);
        out.distance = Math.round(distKm * 100) / 100;
        out.distanceUnit = 'km';
      }
    }
    return out;
  });

  const totalPages = Math.ceil(total / l);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Bus stops fetched successfully', {
      stops: items,
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

// GET /api/v1/bus-stops/nearby?lat=&lng=&radius=&limit=
exports.getNearbyBusStops = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 10, limit = 25 } = req.query;

  if (!lat || !lng) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Latitude and longitude are required');
  }

  const cacheKey = `nearby_bus_stops:${lat}:${lng}:${radius}:${limit}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res
      .status(StatusCodes.OK)
      .json(new ApiResponse(StatusCodes.OK, 'Nearby bus stops fetched (cache)', cached));
  }

  const radKm = Number(radius);
  const lmt = Math.min(parseInt(limit), 100);

  const stops = await BusStop.find({
    location: {
      $near: {
        $geometry: { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
        $maxDistance: radKm * 1000
      }
    }
  })
    .limit(lmt)
    .select('name stop_code city country tz location amenities popularity viewCount')
    .lean();

  const enriched = stops.map((s) => {
    const [lngS, latS] = s.location.coordinates;
    const distKm = locationService.calculateDistance(parseFloat(lat), parseFloat(lng), latS, lngS);
    return {
      ...s,
      distance: Math.round(distKm * 100) / 100,
      distanceUnit: 'km',
      geoUri: `geo:${latS},${lngS}`
    };
  });

  const payload = {
    stops: enriched,
    center: { lat: parseFloat(lat), lng: parseFloat(lng) },
    radius: radKm,
    totalFound: enriched.length,
    generatedAt: toISO()
  };

  await cacheService?.set?.(cacheKey, payload, 600);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Nearby bus stops fetched', payload));
});

// GET /api/v1/bus-stops/suggest?q=&limit=
exports.suggestBusStops = asyncHandler(async (req, res) => {
  const { q = '', limit = 8 } = req.query;

  if (!q || String(q).trim().length < 2) {
    return res
      .status(StatusCodes.OK)
      .json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: [] }));
  }

  const lmt = Math.min(parseInt(limit), 20);

  const suggestions = await BusStop.find({
    $or: [
      { name: new RegExp(q, 'i') },
      { city: new RegExp(q, 'i') },
      { country: new RegExp(q, 'i') },
      { stop_code: new RegExp(`^${q}$`, 'i') }
    ]
  })
    .limit(lmt)
    .sort({ popularity: -1, viewCount: -1 })
    .select('name stop_code city country tz location')
    .lean();

  const mapped = suggestions.map((s) => {
    const [lngS, latS] = s?.location?.coordinates || [null, null];
    return {
      id: s._id,
      name: s.name,
      stop_code: s.stop_code || null,
      city: s.city || null,
      country: s.country || null,
      tz: s.tz || null,
      geoUri: latS && lngS ? `geo:${latS},${lngS}` : null
    };
  });

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: mapped }));
});

// GET /api/v1/bus-stops/:idOrCode
// Supports MongoID or stop_code lookup
exports.getBusStopByIdOrCode = asyncHandler(async (req, res) => {
  const { idOrCode } = req.params;
  const key = String(idOrCode).trim();

  let stop = null;
  const isObjectId = /^[a-f\d]{24}$/i.test(key);
  if (isObjectId) {
    stop = await BusStop.findById(key)
      .select('name stop_code city country tz location amenities popularity viewCount createdAt updatedAt')
      .lean();
  } else {
    stop = await BusStop.findOne({ stop_code: new RegExp(`^${key}$`, 'i') })
      .select('name stop_code city country tz location amenities popularity viewCount createdAt updatedAt')
      .lean();
  }

  if (!stop) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Bus stop not found');
  }

  if (stop?.location?.coordinates) {
    const [lngS, latS] = stop.location.coordinates;
    stop.geoUri = `geo:${latS},${lngS}`;
  }

  await BusStop.findByIdAndUpdate(stop._id, { $inc: { viewCount: 1 } }).catch(() => {});

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Bus stop fetched', stop));
});

// GET /api/v1/bus-stops/:id/serving-buses?limit=20
// List bus trips that serve this stop (ordered by popularity / departure time if available)
exports.getServingBuses = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { limit = 20 } = req.query;

  const lmt = Math.min(parseInt(limit), 100);

  const trips = await Bus.find({ 'stops.stopRefId': id })
    .limit(lmt)
    .sort({ popularity: -1, viewCount: -1 })
    .select('name number operator classes amenities stops fares')
    .lean();

  const mapped = trips.map((t) => {
    const atIdx = (t.stops || []).findIndex((s) => String(s.stopRefId) === String(id));
    const leg = atIdx >= 0 ? t.stops[atIdx] : null;
    return {
      id: t._id,
      name: t.name || t.number,
      operator: t.operator || null,
      classes: t.classes || [],
      amenities: t.amenities || [],
      arrival: leg?.arr || null,
      departure: leg?.dep || null,
      platform: leg?.platform || leg?.bay || null,
      indicativeFare: t.fares || null
    };
  });

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Serving buses fetched', { trips: mapped, generatedAt: toISO() }));
});

// GET /api/v1/bus-stops/geojson
// RFC 7946 FeatureCollection of bus stops for maps/clustering
exports.getBusStopsGeoJSON = asyncHandler(async (req, res) => {
  const filter = buildStopFilter(req.query);
  const { limit = 2000 } = req.query;

  const rows = await BusStop.find(filter)
    .limit(Math.min(parseInt(limit), 5000))
    .select('name stop_code city country tz location amenities')
    .lean();

  const features = rows
    .filter((s) => s?.location?.coordinates && Array.isArray(s.location.coordinates))
    .map((s) => ({
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: s.location.coordinates // [lng,lat]
      },
      properties: {
        id: s._id,
        type: 'bus_stop',
        name: s.name,
        stop_code: s.stop_code || null,
        city: s.city || null,
        country: s.country || null,
        tz: s.tz || null,
        geo: s.location?.coordinates ? `geo:${s.location.coordinates},${s.location.coordinates}` : null
      }
    }));

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});

// Optional: GET /api/v1/bus-stops/bbox?minLng=&minLat=&maxLng=&maxLat=&limit=
exports.getByBBox = asyncHandler(async (req, res) => {
  const { minLng, minLat, maxLng, maxLat, limit = 2000 } = req.query;
  if (
    [minLng, minLat, maxLng, maxLat].some((v) => v === undefined) ||
    [minLng, minLat, maxLng, maxLat].map(Number).some((n) => Number.isNaN(n))
  ) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'minLng,minLat,maxLng,maxLat are required and must be numbers');
  }

  const poly = {
    type: 'Polygon',
    coordinates: [[
      [Number(minLng), Number(minLat)],
      [Number(maxLng), Number(minLat)],
      [Number(maxLng), Number(maxLat)],
      [Number(minLng), Number(maxLat)],
      [Number(minLng), Number(minLat)]
    ]]
  };

  const rows = await BusStop.find({
    isActive: { $ne: false },
    location: { $geoWithin: { $geometry: poly } }
  })
    .limit(Math.min(parseInt(limit), 5000))
    .select('name stop_code city country tz location');

  const features = rows.map((s) => ({
    type: 'Feature',
    geometry: { type: 'Point', coordinates: s.location.coordinates },
    properties: {
      id: s._id,
      type: 'bus_stop',
      name: s.name,
      stop_code: s.stop_code || null,
      city: s.city || null,
      country: s.country || null,
      tz: s.tz || null,
      geo: `geo:${s.location.coordinates},${s.location.coordinates}`
    }
  }));

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});
