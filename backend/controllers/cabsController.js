// C:\flutterapp\myapp\backend\controllers\cabsController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Services (as planned in upgrade)
const cabService = require('../services/cabService');                 // quotes, booking, live, providers, classes
const locationService = require('../services/locationService');       // distance calc, haversine
const mapService = require('../services/mapService');                 // RFC 7946 GeoJSON helpers
const cacheService = require('../services/cacheService');             // optional redis
const directionsService = require('../services/directionsService');   // routing/eta if available

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601
const isNum = (v) => typeof v === 'number' && Number.isFinite(v);
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));

function validateCoords(obj, prefix = '') {
  if (!obj || !isNum(parseFloat(obj.lat)) || !isNum(parseFloat(obj.lng))) {
    throw new ApiError(
      StatusCodes.BAD_REQUEST,
      `${prefix} coordinates (lat,lng) are required and must be numbers`
    );
  }
}

// POST /api/v1/cabs/quote
// Body: { pickup:{lat,lng}, drop:{lat,lng}, whenISO, classCode, passengers, promoCode }
exports.getQuote = asyncHandler(async (req, res) => {
  const { pickup, drop, whenISO, classCode, passengers = 1, promoCode } = req.body || {};

  validateCoords(pickup, 'pickup');
  validateCoords(drop, 'drop');

  const quote = await cabService.getQuote({
    pickup: { lat: parseFloat(pickup.lat), lng: parseFloat(pickup.lng) },
    drop: { lat: parseFloat(drop.lat), lng: parseFloat(drop.lng) },
    whenISO: whenISO || toISO(),
    classCode,
    passengers,
    promoCode
  }); // { currency, base, distanceKm, durationMin, surge, total, breakdown, provider, classCode, etaMin, expiresAtISO }

  if (!quote) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Quote not available for the specified route/time');
  }

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Cab quote generated', {
      ...quote,
      generatedAt: toISO()
    })
  );
});

// GET /api/v1/cabs/nearby?lat=&lng=&radius=&limit=&class=
// Lists nearby vehicles for the map and pickup screen
exports.getNearbyVehicles = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 5, limit = 30, class: classCode } = req.query;
  if (!lat || !lng) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Latitude and longitude are required');
  }

  const cacheKey = `cabs:nearby:${lat}:${lng}:${radius}:${limit}:${classCode || 'all'}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res
      .status(StatusCodes.OK)
      .json(new ApiResponse(StatusCodes.OK, 'Nearby vehicles fetched (cache)', cached));
  }

  const vehicles = await cabService.findNearbyVehicles({
    lat: parseFloat(lat),
    lng: parseFloat(lng),
    radiusKm: Number(radius),
    limit: clamp(parseInt(limit), 1, 200),
    classCode
  }); // [{ id, classCode, provider, location:{lat,lng}, heading, speedKph, etaMin }]

  const enriched = vehicles.map((v) => ({
    ...v,
    geoUri: isNum(v?.location?.lat) && isNum(v?.location?.lng)
      ? `geo:${v.location.lat},${v.location.lng}`
      : null
  }));

  const payload = {
    vehicles: enriched,
    center: { lat: parseFloat(lat), lng: parseFloat(lng) },
    radiusKm: Number(radius),
    totalFound: enriched.length,
    generatedAt: toISO()
  };

  await cacheService?.set?.(cacheKey, payload, 30); // 30 seconds
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Nearby vehicles fetched', payload));
});

// POST /api/v1/cabs/book
// Body: { pickup:{lat,lng,address}, drop:{lat,lng,address}, whenISO, classCode, passengers, paymentMethod, preferences, quoteId }
exports.bookRide = asyncHandler(async (req, res) => {
  const {
    pickup,
    drop,
    whenISO,
    classCode,
    passengers = 1,
    paymentMethod,
    preferences,
    quoteId
  } = req.body || {};

  validateCoords(pickup, 'pickup');
  validateCoords(drop, 'drop');

  const ride = await cabService.createRide({
    pickup,
    drop,
    whenISO: whenISO || toISO(),
    classCode,
    passengers,
    paymentMethod,
    preferences,
    quoteId,
    userId: req.user?.id
  }); // { rideId, status, provider, classCode, driver, vehicle, etaMin, payment: { paymentUrl?, expiresAtISO? } }

  if (!ride) {
    throw new ApiError(StatusCodes.INTERNAL_SERVER_ERROR, 'Failed to create ride');
  }

  return res.status(StatusCodes.CREATED).json(
    new ApiResponse(StatusCodes.CREATED, 'Ride created', {
      ...ride,
      generatedAt: toISO()
    })
  );
});

// GET /api/v1/cabs/rides/:id
// Returns live ride status for tracking screen
exports.getRideStatus = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const status = await cabService.getRideStatus(id); 
  // { rideId, status, stage, pickup, drop, driver, vehicle, current:{lat,lng,heading,speedKph,lastUpdatedISO}, 
  //   etaToPickupMin, etaToDropMin, distanceRemainingKm, route: { coordinates:[ [lng,lat], ... ] } }

  if (!status) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Ride not found');
  }

  const enriched = { ...status };
  if (status?.current?.lat && status?.current?.lng) {
    enriched.current.geoUri = `geo:${status.current.lat},${status.current.lng}`;
  }

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Ride status fetched', {
      ...enriched,
      generatedAt: toISO()
    })
  );
});

// POST /api/v1/cabs/rides/:id/cancel
// Body: { reasonCode, note }
exports.cancelRide = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { reasonCode, note } = req.body || {};

  const result = await cabService.cancelRide({ rideId: id, reasonCode, note, userId: req.user?.id });
  if (!result?.success) {
    throw new ApiError(StatusCodes.BAD_REQUEST, result?.message || 'Unable to cancel ride at this stage');
  }

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Ride cancelled', { rideId: id, ...result, generatedAt: toISO() }));
});

// GET /api/v1/cabs/providers
exports.getProviders = asyncHandler(async (_req, res) => {
  const cacheKey = 'cabs:providers';
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Providers fetched (cache)', cached));
  }

  const providers = await cabService.getProviders(); // [{ code, name, logo, regions }]
  const payload = { providers, generatedAt: toISO() };
  await cacheService?.set?.(cacheKey, payload, 3600);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Providers fetched', payload));
});

// GET /api/v1/cabs/classes
exports.getVehicleClasses = asyncHandler(async (_req, res) => {
  const cacheKey = 'cabs:classes';
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Classes fetched (cache)', cached));
  }

  const classes = await cabService.getVehicleClasses();
  const payload = { classes, generatedAt: toISO() };
  await cacheService?.set?.(cacheKey, payload, 3600);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Classes fetched', payload));
});

// GET /api/v1/cabs/eta?fromLat=&fromLng=&toLat=&toLng=&whenISO=
exports.getEta = asyncHandler(async (req, res) => {
  const { fromLat, fromLng, toLat, toLng, whenISO } = req.query;

  if (![fromLat, fromLng, toLat, toLng].every((v) => v !== undefined)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'fromLat, fromLng, toLat, toLng are required');
  }

  const eta = await cabService.getEta({
    from: { lat: parseFloat(fromLat), lng: parseFloat(fromLng) },
    to: { lat: parseFloat(toLat), lng: parseFloat(toLng) },
    whenISO: whenISO || toISO()
  }); // { distanceKm, durationMin, route: { coordinates:[ [lng,lat], ... ] } }

  if (!eta) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'ETA not available');
  }

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'ETA computed', {
      ...eta,
      generatedAt: toISO()
    })
  );
});

// GET /api/v1/cabs/rides/:id/geojson
// Returns RFC 7946 FeatureCollection with LineString route and current position point
exports.getRideGeoJSON = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const status = await cabService.getRideStatus(id);
  if (!status?.route?.coordinates || !Array.isArray(status.route.coordinates)) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Route not available for this ride');
  }

  const features = [];

  // Route LineString (must be [lng,lat] per RFC 7946)
  features.push({
    type: 'Feature',
    geometry: {
      type: 'LineString',
      coordinates: status.route.coordinates
    },
    properties: { kind: 'cab_route', rideId: id }
  });

  // Current position as Point
  if (status?.current?.lat && status?.current?.lng) {
    features.push({
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: [status.current.lng, status.current.lat]
      },
      properties: {
        kind: 'vehicle_position',
        rideId: id,
        heading: status.current.heading || null,
        speedKph: status.current.speedKph || null,
        lastUpdatedISO: status.current.lastUpdatedISO || toISO(),
        geo: `geo:${status.current.lat},${status.current.lng}`
      }
    });
  }

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});
