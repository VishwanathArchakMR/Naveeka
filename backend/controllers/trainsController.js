// C:\flutterapp\myapp\backend\controllers\trainsController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const Train = require('../models/Train');
const TrainStation = require('../models/TrainStation');

// Services
const trainService = require('../services/trainService');           // search, fares, seatmap, live, pnr, booking
const locationService = require('../services/locationService');     // distance calc
const mapService = require('../services/mapService');               // shapes/geojson helpers
const cacheService = require('../services/cacheService');           // Redis (optional)

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601 UTC
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));

/**
 * POST /api/v1/trains/search
 * Body: { from, to, date, passengers:{adults,children}, classCode?, quota?, sortBy?, sortOrder?, page?, limit? }
 * - from/to: { stationId | code | coords:{lat,lng} }
 */
exports.searchTrains = asyncHandler(async (req, res) => {
  const {
    from,
    to,
    date,
    passengers = { adults: 1, children: 0 },
    classCode,
    quota,
    sortBy = 'relevance', // price|duration|departure|arrival|stops|relevance
    sortOrder = 'asc',
    page = 1,
    limit = 20,
    userLocation
  } = req.body || {};

  if (!from || !to || !date) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'from, to and date are required for train search');
  }

  const p = clamp(parseInt(page || 1), 1, 200);
  const l = clamp(parseInt(limit || 20), 1, 100);

  const result = await trainService.search({
    from,
    to,
    date,
    passengers,
    classCode,
    quota,
    sortBy,
    sortOrder,
    page: p,
    limit: l
  }); // { trips:[], facets:{}, pagination:{page,limit,total,totalPages}, processingTimeMs }

  // Enrich with distance to boarding if provided
  const enrichedTrips = (result.trips || []).map((t) => {
    const enriched = { ...t };
    if (userLocation?.lat && userLocation?.lng && t?.from?.location?.coordinates) {
      const [lngA, latA] = t.from.location.coordinates;
      const distKm = locationService.calculateDistance(
        parseFloat(userLocation.lat),
        parseFloat(userLocation.lng),
        latA,
        lngA
      );
      enriched.boardingDistanceKm = Math.round(distKm * 100) / 100;
    }
    return enriched;
  });

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Train search completed', {
      trips: enrichedTrips,
      pagination: result.pagination || { page: p, limit: l, total: enrichedTrips.length, totalPages: 1 },
      facets: result.facets || {},
      generatedAt: toISO()
    })
  );
});

/**
 * GET /api/v1/trains/:id
 * Returns full train trip details with ordered stops (GTFS stop_times-like structure)
 */
exports.getTrainById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const trip = await Train.findById(id)
    .select(
      'id number name operator serviceDays validity classes amenities policies ' +
        'stops fares routeShapeRef rating reviews createdAt updatedAt'
    )
    .lean();

  if (!trip) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Train trip not found');
  }

  // Pull stop metadata
  const stopIds = (trip.stops || []).map((s) => s.stationRefId).filter(Boolean);
  const stopsMap = stopIds.length
    ? (
        await TrainStation.find({ _id: { $in: stopIds } })
          .select('name city country tz location station_code amenities')
          .lean()
      ).reduce((acc, s) => ((acc[String(s._id)] = s), acc), {})
    : {};

  const stops = (trip.stops || [])
    .sort((a, b) => (a.seq || 0) - (b.seq || 0))
    .map((s) => {
      const meta = stopsMap[String(s.stationRefId)] || {};
      const feature = meta?.location?.coordinates
        ? { geoUri: `geo:${meta.location.coordinates},${meta.location.coordinates}` }
        : {};
      return {
        seq: s.seq,
        stationRefId: s.stationRefId,
        station_code: meta.station_code || null,
        name: meta.name || s.name,
        city: meta.city || null,
        country: meta.country || null,
        tz: meta.tz || null,
        arr: s.arr, // ISO 8601 (local with offset expected)
        dep: s.dep, // ISO 8601 (local with offset expected)
        platform: s.platform || null,
        distance_km: s.distance_km || null,
        amenities: meta.amenities || [],
        ...feature
      };
    });

  const response = {
    id: trip._id,
    number: trip.number,
    name: trip.name,
    operator: trip.operator,
    classes: trip.classes,
    amenities: trip.amenities || [],
    policies: trip.policies || {},
    serviceDays: trip.serviceDays || {},
    validity: trip.validity || {},
    fares: trip.fares || [],
    rating: trip.rating || null,
    reviews: trip.reviews || null,
    stops,
    createdAt: trip.createdAt,
    updatedAt: trip.updatedAt
  };

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Train trip fetched', response));
});

/**
 * GET /api/v1/trains/:id/route
 * Returns RFC 7946 FeatureCollection with LineString for route and stop Points
 */
exports.getTrainRoute = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const train = await Train.findById(id).select('id name number routeShape coordinatesGeoJSON stops').lean();
  if (!train) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Train trip not found');
  }

  // Build route geometry
  let line = null;
  if (train?.coordinatesGeoJSON?.type === 'LineString') {
    line = train.coordinatesGeoJSON; // precomputed [lng,lat]
  } else if (Array.isArray(train?.routeShape) && train.routeShape.length) {
    line = mapService.toLineString(train.routeShape); // expects [lng,lat]
  }

  // Load station docs for stop Points
  const stationIds = (train.stops || []).map((s) => s.stationRefId).filter(Boolean);
  const stationDocs = stationIds.length
    ? await TrainStation.find({ _id: { $in: stationIds } })
        .select('name city country location tz station_code')
        .lean()
    : [];
  const stationMap = stationDocs.reduce((acc, s) => ((acc[String(s._id)] = s), acc), {});

  const stopFeatures = (train.stops || [])
    .sort((a, b) => (a.seq || 0) - (b.seq || 0))
    .map((s) => {
      const d = stationMap[String(s.stationRefId)] || {};
      const coords = d?.location?.coordinates;
      if (!coords) return null;
      return {
        type: 'Feature',
        geometry: { type: 'Point', coordinates: coords },
        properties: {
          seq: s.seq,
          stationRefId: s.stationRefId,
          name: d.name || s.name,
          station_code: d.station_code || null,
          city: d.city || null,
          country: d.country || null,
          tz: d.tz || null,
          arr: s.arr || null,
          dep: s.dep || null,
          geo: `geo:${coords},${coords}`
        }
      };
    })
    .filter(Boolean);

  const fc = {
    type: 'FeatureCollection',
    features: [
      ...(line
        ? [
            {
              type: 'Feature',
              geometry: line,
              properties: { id: train._id, kind: 'train_route', name: train.name || train.number }
            }
          ]
        : []),
      ...stopFeatures
    ],
    generatedAt: toISO()
  };

  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});

/**
 * GET /api/v1/trains/live/:id
 * Returns live train position/ETA if available
 */
exports.getLiveStatus = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const live = await trainService.getLiveStatus(id); 
  // { lat,lng,speedKph,heading,lastUpdatedISO,nextStationRefId,etaToNextISO, delayMin?, currentStationRefId? }

  if (!live) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Live status not available');
  }

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Live status fetched', {
      ...live,
      generatedAt: toISO()
    })
  );
});

/**
 * GET /api/v1/trains/operators
 * Returns operators with trip counts and fare ranges
 */
exports.getOperators = asyncHandler(async (req, res) => {
  const cacheKey = 'train_operators_v1';
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Operators fetched (cache)', cached));
  }

  const agg = await Train.aggregate([
    {
      $group: {
        _id: '$operator',
        trips: { $sum: 1 },
        minFare: { $min: { $min: '$fares.min' } },
        maxFare: { $max: { $max: '$fares.max' } }
      }
    },
    { $sort: { trips: -1 } },
    {
      $project: {
        _id: 0,
        operator: '$_id',
        trips: 1,
        minFare: 1,
        maxFare: 1
      }
    }
  ]);

  const payload = { operators: agg, generatedAt: toISO() };
  await cacheService?.set?.(cacheKey, payload, 3600);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Operators fetched', payload));
});

/**
 * GET /api/v1/trains/:id/seatmap?fromStationId=&toStationId=&date=&class=
 * Returns seat/berth layout and availability for a leg/date/class
 */
exports.getSeatMap = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { fromStationId, toStationId, date, class: classCode } = req.query;

  if (!fromStationId || !toStationId || !date) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'fromStationId, toStationId and date are required');
  }

  const seatmap = await trainService.getSeatMap({
    trainId: id,
    fromStationId,
    toStationId,
    date,
    classCode
  }); // { layout, berths[], available[], blocked[], pricingRules }

  if (!seatmap) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Seat map not available');
  }

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Seat map fetched', { ...seatmap, generatedAt: toISO() }));
});

/**
 * POST /api/v1/trains/quote
 * Body: { trainId, fromStationId, toStationId, date, passengers, class, quota, addons }
 * Returns fare quote with currency and hold expiry
 */
exports.getFareQuote = asyncHandler(async (req, res) => {
  const { trainId, fromStationId, toStationId, date, passengers, class: classCode, quota, addons } = req.body || {};

  if (!trainId || !fromStationId || !toStationId || !date || !passengers) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'trainId, fromStationId, toStationId, date, passengers are required');
  }

  const quote = await trainService.getFareQuote({
    trainId,
    fromStationId,
    toStationId,
    date,
    passengers,
    classCode,
    quota,
    addons
  }); // { currency, base, taxes, fees, total, expiresAtISO }

  if (!quote) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Fare quote not available');
  }

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Fare quote generated', { ...quote, generatedAt: toISO() }));
});

/**
 * GET /api/v1/trains/pnr/:pnr
 * Returns PNR status (if supported by provider)
 */
exports.getPNRStatus = asyncHandler(async (req, res) => {
  const { pnr } = req.params;

  const status = await trainService.getPNRStatus({ pnr }); 
  // { pnr, status, passengers:[{name,age,berth,coach,status}], train, journey:{date,from,to}, lastUpdatedISO }

  if (!status) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'PNR not found');
  }

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'PNR status fetched', { ...status, generatedAt: toISO() }));
});

/**
 * GET /api/v1/trains/suggest?q=&limit=
 * Suggest trains/operators/routes for search bars
 */
exports.suggest = asyncHandler(async (req, res) => {
  const { q = '', limit = 8 } = req.query;
  if (!q || String(q).trim().length < 2) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: [] }));
  }

  const lmt = clamp(parseInt(limit), 1, 20);
  const suggestions = await Train.find({
    $or: [
      { name: new RegExp(q, 'i') },
      { number: new RegExp(q, 'i') },
      { operator: new RegExp(q, 'i') },
      { 'stops.name': new RegExp(q, 'i') }
    ]
  })
    .limit(lmt)
    .select('name number operator stops')
    .lean();

  const mapped = suggestions.map((t) => ({
    id: t._id,
    label: `${t.name || t.number} · ${t.operator}`,
    from: t.stops?.[0]?.name || null,
    to: t.stops?.[t.stops.length - 1]?.name || null
  }));

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: mapped }));
});
