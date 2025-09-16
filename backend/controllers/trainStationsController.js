// C:\flutterapp\myapp\backend\controllers\trainStationsController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const TrainStation = require('../models/TrainStation');
const Train = require('../models/Train');

// Services
const cacheService = require('../services/cacheService');       // optional Redis
const locationService = require('../services/locationService'); // distance calc
const mapService = require('../services/mapService');           // geo helpers

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const parseCSV = (v) => (v ? String(v).split(',').map((s) => s.trim()).filter(Boolean) : []);
const isFiniteNumber = (n) => typeof n === 'number' && Number.isFinite(n);

// Build Mongo filter from query, mirroring GTFS stops fields where applicable
function buildStationFilter(q) {
  const {
    q: search,
    city,
    country,
    tz,
    station_code,     // GTFS-like rider-facing code
    hasStationCode,
    lat,
    lng,
    radius = 0,
    tags
  } = q;

  const filter = { isActive: { $ne: false } };

  if (search) {
    filter.$or = [
      { name: new RegExp(search, 'i') },
      { city: new RegExp(search, 'i') },
      { country: new RegExp(search, 'i') },
      { station_code: new RegExp(`^${search}$`, 'i') }
    ];
  }

  if (city) filter.city = new RegExp(city, 'i');
  if (country) filter.country = new RegExp(country, 'i');
  if (tz) filter.tz = new RegExp(tz, 'i');

  if (station_code) filter.station_code = new RegExp(`^${station_code}$`, 'i');
  if (hasStationCode === 'true') filter.station_code = { $exists: true, $ne: '' };

  if (tags) {
    const t = parseCSV(tags);
    if (t.length) filter.tags = { $in: t };
  }

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

// GET /api/v1/train-stations
// List stations with filters, pagination, sorting, optional distance enrichment
exports.getTrainStations = asyncHandler(async (req, res) => {
  const {
    page = 1,
    limit = 25,
    sortBy = 'popularity', // name|country|distance|popularity
    sortOrder = 'desc',
    lat,
    lng
  } = req.query;

  const filter = buildStationFilter(req.query);

  const sort = {};
  switch (sortBy) {
    case 'name':
      sort.name = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'country':
      sort.country = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'distance':
      // $near sorts by distance when used; otherwise fallback
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
    TrainStation.find(filter)
      .sort(sort)
      .skip(skip)
      .limit(l)
      .select('name station_code city country tz location amenities platforms tags popularity viewCount createdAt updatedAt')
      .lean(),
    TrainStation.countDocuments(filter)
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
    new ApiResponse(StatusCodes.OK, 'Train stations fetched successfully', {
      stations: items,
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

// GET /api/v1/train-stations/nearby?lat=&lng=&radius=&limit=
exports.getNearbyTrainStations = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 25, limit = 25 } = req.query;

  if (!lat || !lng) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Latitude and longitude are required');
  }

  const cacheKey = `nearby_train_stations:${lat}:${lng}:${radius}:${limit}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res
      .status(StatusCodes.OK)
      .json(new ApiResponse(StatusCodes.OK, 'Nearby train stations fetched (cache)', cached));
  }

  const radKm = Number(radius);
  const lmt = Math.min(parseInt(limit), 100);

  const rows = await TrainStation.find({
    location: {
      $near: {
        $geometry: { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
        $maxDistance: radKm * 1000
      }
    }
  })
    .limit(lmt)
    .select('name station_code city country tz location amenities platforms popularity viewCount')
    .lean();

  const enriched = rows.map((s) => {
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
    stations: enriched,
    center: { lat: parseFloat(lat), lng: parseFloat(lng) },
    radius: radKm,
    totalFound: enriched.length,
    generatedAt: toISO()
  };

  await cacheService?.set?.(cacheKey, payload, 600); // 10 minutes
  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Nearby train stations fetched', payload));
});

// GET /api/v1/train-stations/suggest?q=&limit=
exports.suggestTrainStations = asyncHandler(async (req, res) => {
  const { q = '', limit = 8 } = req.query;

  if (!q || String(q).trim().length < 2) {
    return res
      .status(StatusCodes.OK)
      .json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: [] }));
  }

  const lmt = Math.min(parseInt(limit), 20);

  const suggestions = await TrainStation.find({
    $or: [
      { name: new RegExp(q, 'i') },
      { city: new RegExp(q, 'i') },
      { country: new RegExp(q, 'i') },
      { station_code: new RegExp(`^${q}$`, 'i') }
    ]
  })
    .limit(lmt)
    .sort({ popularity: -1, viewCount: -1 })
    .select('name station_code city country tz location')
    .lean();

  const mapped = suggestions.map((s) => {
    const [lngS, latS] = s?.location?.coordinates || [null, null];
    return {
      id: s._id,
      name: s.name,
      station_code: s.station_code || null,
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

// GET /api/v1/train-stations/:idOrCode
// Supports MongoID or station_code lookup
exports.getTrainStationByIdOrCode = asyncHandler(async (req, res) => {
  const { idOrCode } = req.params;
  const key = String(idOrCode).trim();

  let station = null;
  const isObjectId = /^[a-f\d]{24}$/i.test(key);
  if (isObjectId) {
    station = await TrainStation.findById(key)
      .select('name station_code city country tz location amenities platforms tags popularity viewCount createdAt updatedAt')
      .lean();
  } else {
    station = await TrainStation.findOne({ station_code: new RegExp(`^${key}$`, 'i') })
      .select('name station_code city country tz location amenities platforms tags popularity viewCount createdAt updatedAt')
      .lean();
  }

  if (!station) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Train station not found');
  }

  if (station?.location?.coordinates) {
    const [lngS, latS] = station.location.coordinates;
    station.geoUri = `geo:${latS},${lngS}`;
  }

  await TrainStation.findByIdAndUpdate(station._id, { $inc: { viewCount: 1 } }).catch(() => {});

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Train station fetched', station));
});

// GET /api/v1/train-stations/:id/serving-trains?limit=20
exports.getServingTrains = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { limit = 20 } = req.query;

  const lmt = Math.min(parseInt(limit), 100);

  const trips = await Train.find({ 'stops.stationRefId': id })
    .limit(lmt)
    .sort({ popularity: -1, viewCount: -1 })
    .select('name number operator classes amenities stops fares')
    .lean();

  const mapped = trips.map((t) => {
    const atIdx = (t.stops || []).findIndex((s) => String(s.stationRefId) === String(id));
    const leg = atIdx >= 0 ? t.stops[atIdx] : null;
    return {
      id: t._id,
      name: t.name || t.number,
      operator: t.operator || null,
      classes: t.classes || [],
      amenities: t.amenities || [],
      arrival: leg?.arr || null,
      departure: leg?.dep || null,
      platform: leg?.platform || null,
      indicativeFare: t.fares || null
    };
  });

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Serving trains fetched', { trips: mapped, generatedAt: toISO() }));
});

// GET /api/v1/train-stations/geojson
// RFC 7946 FeatureCollection for map layers/clustering
exports.getTrainStationsGeoJSON = asyncHandler(async (req, res) => {
  const filter = buildStationFilter(req.query);
  const { limit = 2000 } = req.query;

  const rows = await TrainStation.find(filter)
    .limit(Math.min(parseInt(limit), 5000))
    .select('name station_code city country tz location amenities platforms tags')
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
        type: 'train_station',
        name: s.name,
        station_code: s.station_code || null,
        city: s.city || null,
        country: s.country || null,
        tz: s.tz || null,
        platforms: s.platforms || null,
        geo: s.location?.coordinates ? `geo:${s.location.coordinates},${s.location.coordinates}` : null
      }
    }));

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});

// GET /api/v1/train-stations/bbox?minLng=&minLat=&maxLng=&maxLat=&limit=
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

  const rows = await TrainStation.find({
    isActive: { $ne: false },
    location: { $geoWithin: { $geometry: poly } }
  })
    .limit(Math.min(parseInt(limit), 5000))
    .select('name station_code city country tz location');

  const features = rows.map((s) => ({
    type: 'Feature',
    geometry: { type: 'Point', coordinates: s.location.coordinates },
    properties: {
      id: s._id,
      type: 'train_station',
      name: s.name,
      station_code: s.station_code || null,
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
