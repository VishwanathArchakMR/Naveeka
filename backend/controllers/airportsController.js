// C:\flutterapp\myapp\backend\controllers\airportsController.js

const Airport = require('../models/Airport');
const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Services expected from upgrade plan
const locationService = require('../services/locationService'); // distance, bbox, geospatial helpers
const mapService = require('../services/mapService'); // GeoJSON helpers (RFC 7946)
const cacheService = require('../services/cacheService'); // optional Redis cache if available

// Normalize and parse helpers
const parseFloatOrNull = (v) => (v === undefined || v === null || v === '' ? null : parseFloat(v));
const toISO = (d = new Date()) => d.toISOString();

// Build MongoDB filter from query params
function buildAirportFilter(q) {
  const {
    country,
    city,
    tz,
    iata,
    icao,
    hasIata,
    hasIcao,
    lat,
    lng,
    radius = 0,
    q: search
  } = q;

  const filter = { isActive: { $ne: false } };

  if (country) filter.country = new RegExp(country, 'i');
  if (city) filter.city = new RegExp(city, 'i');
  if (tz) filter.tz = new RegExp(tz, 'i');

  if (iata) filter.iata = new RegExp(`^${iata}$`, 'i');
  if (icao) filter.icao = new RegExp(`^${icao}$`, 'i');

  if (hasIata === 'true') filter.iata = { $exists: true, $ne: '' };
  if (hasIcao === 'true') filter.icao = { $exists: true, $ne: '' };

  if (search) {
    filter.$or = [
      { name: new RegExp(search, 'i') },
      { city: new RegExp(search, 'i') },
      { country: new RegExp(search, 'i') },
      { iata: new RegExp(`^${search}$`, 'i') },
      { icao: new RegExp(`^${search}$`, 'i') }
    ];
  }

  // Geo $near if lat/lng present
  if (lat && lng && parseFloat(lat) && parseFloat(lng) && Number(radius) > 0) {
    filter.location = {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: [parseFloat(lng), parseFloat(lat)]
        },
        $maxDistance: Number(radius) * 1000 // km -> meters
      }
    };
  }

  return filter;
}

// GET /api/v1/airports
// List airports with filters, pagination, sorting, and optional distance enrichment
exports.getAirports = asyncHandler(async (req, res) => {
  const {
    page = 1,
    limit = 20,
    sortBy = 'popularity', // name | country | distance | popularity
    sortOrder = 'desc',
    lat,
    lng
  } = req.query;

  const filter = buildAirportFilter(req.query);

  const sort = {};
  switch (sortBy) {
    case 'name':
      sort.name = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'country':
      sort.country = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'distance':
      // If $near used, Mongo already sorts by distance; else fallback
      sort.name = 1;
      break;
    case 'popularity':
    default:
      sort.popularity = -1;
      sort.viewCount = -1;
      sort.createdAt = -1;
      break;
  }

  const p = parseInt(page);
  const l = parseInt(limit);
  const skip = (p - 1) * l;

  const [rows, total] = await Promise.all([
    Airport.find(filter)
      .sort(sort)
      .skip(skip)
      .limit(l)
      .select('name iata icao city country tz location popularity viewCount createdAt updatedAt')
      .lean(),
    Airport.countDocuments(filter)
  ]);

  // Enrich with distance and geo URI if user coords present
  const uLat = parseFloatOrNull(lat);
  const uLng = parseFloatOrNull(lng);

  const enriched = rows.map((a) => {
    const item = { ...a };
    if (a?.location?.coordinates && !Number.isNaN(uLat) && !Number.isNaN(uLng)) {
      const [lngA, latA] = a.location.coordinates;
      const distKm = locationService.calculateDistance(uLat, uLng, latA, lngA);
      item.distance = Math.round(distKm * 100) / 100;
      item.distanceUnit = 'km';
    }
    if (a?.location?.coordinates) {
      const [lngA, latA] = a.location.coordinates;
      item.geoUri = `geo:${latA},${lngA}`;
    }
    return item;
  });

  const totalPages = Math.ceil(total / l);

  return res
    .status(StatusCodes.OK)
    .json(
      new ApiResponse(StatusCodes.OK, 'Airports fetched successfully', {
        airports: enriched,
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

// GET /api/v1/airports/nearby?lat=&lng=&radius=&limit=
// Returns airports near a coordinate with optional category/filters
exports.getNearbyAirports = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 50, limit = 20 } = req.query;

  if (!lat || !lng) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Latitude and longitude are required');
  }

  const cacheKey = `nearby_airports:${lat}:${lng}:${radius}:${limit}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res
      .status(StatusCodes.OK)
      .json(new ApiResponse(StatusCodes.OK, 'Nearby airports fetched (cache)', cached));
  }

  const radKm = Number(radius);
  const lmt = parseInt(limit);

  const airports = await Airport.find({
    location: {
      $near: {
        $geometry: { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
        $maxDistance: radKm * 1000
      }
    }
  })
    .limit(lmt)
    .select('name iata icao city country tz location popularity viewCount')
    .lean();

  const enriched = airports.map((a) => {
    const [lngA, latA] = a.location.coordinates;
    const distKm = locationService.calculateDistance(parseFloat(lat), parseFloat(lng), latA, lngA);
    return {
      ...a,
      distance: Math.round(distKm * 100) / 100,
      distanceUnit: 'km',
      geoUri: `geo:${latA},${lngA}`
    };
  });

  const payload = {
    airports: enriched,
    center: { lat: parseFloat(lat), lng: parseFloat(lng) },
    radius: radKm,
    totalFound: enriched.length,
    generatedAt: toISO()
  };

  await cacheService?.set?.(cacheKey, payload, 600); // 10 minutes
  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Nearby airports fetched successfully', payload));
});

// GET /api/v1/airports/suggest?q=del&limit=8
// Lightweight autocomplete for search bars (IATA/ICAO/name/city)
exports.suggestAirports = asyncHandler(async (req, res) => {
  const { q = '', limit = 8 } = req.query;

  if (!q || String(q).trim().length < 2) {
    return res
      .status(StatusCodes.OK)
      .json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: [] }));
  }

  const lmt = Math.min(parseInt(limit), 20);

  const suggestions = await Airport.find({
    $or: [
      { name: new RegExp(q, 'i') },
      { city: new RegExp(q, 'i') },
      { country: new RegExp(q, 'i') },
      { iata: new RegExp(`^${q}$`, 'i') },
      { icao: new RegExp(`^${q}$`, 'i') }
    ]
  })
    .limit(lmt)
    .sort({ popularity: -1, viewCount: -1 })
    .select('name iata icao city country tz location')
    .lean();

  const mapped = suggestions.map((a) => {
    const [lngA, latA] = a?.location?.coordinates || [null, null];
    return {
      id: a._id,
      name: a.name,
      iata: a.iata,
      icao: a.icao,
      city: a.city,
      country: a.country,
      tz: a.tz,
      geoUri: latA && lngA ? `geo:${latA},${lngA}` : null
    };
  });

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: mapped }));
});

// GET /api/v1/airports/:idOrCode
// Supports MongoID, IATA (3 letters), or ICAO (4 letters)
exports.getAirportByIdOrCode = asyncHandler(async (req, res) => {
  const { idOrCode } = req.params;
  const code = String(idOrCode).trim();

  let airport = null;

  const isObjectId = /^[a-f\d]{24}$/i.test(code);
  if (isObjectId) {
    airport = await Airport.findById(code)
      .select('name iata icao city country tz location terminals runways elevation_m popularity viewCount createdAt updatedAt')
      .lean();
  } else {
    // code-based lookup
    if (code.length === 3) {
      airport = await Airport.findOne({ iata: new RegExp(`^${code}$`, 'i') })
        .select('name iata icao city country tz location terminals runways elevation_m popularity viewCount createdAt updatedAt')
        .lean();
    } else if (code.length === 4) {
      airport = await Airport.findOne({ icao: new RegExp(`^${code}$`, 'i') })
        .select('name iata icao city country tz location terminals runways elevation_m popularity viewCount createdAt updatedAt')
        .lean();
    }
  }

  if (!airport) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Airport not found');
  }

  // Enrich with geo URI and increment views
  if (airport?.location?.coordinates) {
    const [lngA, latA] = airport.location.coordinates;
    airport.geoUri = `geo:${latA},${lngA}`;
  }

  await Airport.findByIdAndUpdate(airport._id, { $inc: { viewCount: 1 } }).catch(() => {});

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Airport fetched successfully', airport));
});

// GET /api/v1/airports/geojson
// Returns RFC 7946 FeatureCollection of filtered airports for maps
exports.getAirportsGeoJSON = asyncHandler(async (req, res) => {
  const filter = buildAirportFilter(req.query);
  const { limit = 500 } = req.query;

  const rows = await Airport.find(filter)
    .limit(Math.min(parseInt(limit), 2000))
    .select('name iata icao city country tz location')
    .lean();

  // Build FeatureCollection: coordinates must be [lng, lat]
  const features = rows
    .filter((a) => a?.location?.coordinates && Array.isArray(a.location.coordinates))
    .map((a) => ({
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: a.location.coordinates // [lng, lat] per RFC 7946
      },
      properties: {
        id: a._id,
        type: 'airport',
        name: a.name,
        iata: a.iata || null,
        icao: a.icao || null,
        city: a.city || null,
        country: a.country || null,
        tz: a.tz || null,
        geo: a.location?.coordinates ? `geo:${a.location.coordinates},${a.location.coordinates}` : null
      }
    }));

  const fc = {
    type: 'FeatureCollection',
    features,
    generatedAt: toISO()
  };

  // Optional: content-type for GeoJSON
  res.setHeader('Content-Type', 'application/geo+json');

  return res
    .status(StatusCodes.OK)
    .json(fc);
});

// POST /api/v1/airports/search
// Advanced search via body for complex clients
exports.searchAirports = asyncHandler(async (req, res) => {
  const {
    q,
    country,
    city,
    tz,
    iata,
    icao,
    lat,
    lng,
    radius = 0,
    limit = 20,
    sortBy = 'popularity',
    sortOrder = 'desc'
  } = req.body || {};

  const filter = buildAirportFilter({
    q,
    country,
    city,
    tz,
    iata,
    icao,
    lat,
    lng,
    radius
  });

  const sort = {};
  switch (sortBy) {
    case 'name':
      sort.name = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'country':
      sort.country = sortOrder === 'asc' ? 1 : -1;
      break;
    case 'distance':
      sort.name = 1;
      break;
    case 'popularity':
    default:
      sort.popularity = -1;
      sort.viewCount = -1;
      break;
  }

  const lmt = Math.min(parseInt(limit), 100);

  const rows = await Airport.find(filter)
    .sort(sort)
    .limit(lmt)
    .select('name iata icao city country tz location popularity viewCount')
    .lean();

  const uLat = parseFloatOrNull(lat);
  const uLng = parseFloatOrNull(lng);

  const results = rows.map((a) => {
    const item = { ...a };
    if (a?.location?.coordinates && !Number.isNaN(uLat) && !Number.isNaN(uLng)) {
      const [lngA, latA] = a.location.coordinates;
      const distKm = locationService.calculateDistance(uLat, uLng, latA, lngA);
      item.distance = Math.round(distKm * 100) / 100;
      item.distanceUnit = 'km';
    }
    if (a?.location?.coordinates) {
      const [lngA, latA] = a.location.coordinates;
      item.geoUri = `geo:${latA},${lngA}`;
    }
    return item;
  });

  return res
    .status(StatusCodes.OK)
    .json(
      new ApiResponse(StatusCodes.OK, 'Search completed', {
        results,
        totalFound: results.length,
        generatedAt: toISO()
      })
    );
});
