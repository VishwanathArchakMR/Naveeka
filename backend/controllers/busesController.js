// C:\flutterapp\myapp\backend\controllers\busesController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const Bus = require('../models/Bus');
const BusStop = require('../models/BusStop');

// Services
const busService = require('../services/busService');               // search, pricing, seatmap, live
const locationService = require('../services/locationService');     // distance calc
const mapService = require('../services/mapService');               // shapes/geojson helpers
const cacheService = require('../services/cacheService');           // optional Redis cache

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601 UTC
const parseNum = (v) => (v === undefined || v === null || v === '' ? null : Number(v));
const parseCSV = (v) => (v ? String(v).split(',').map((s) => s.trim()).filter(Boolean) : []);
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));

/**
 * POST /api/v1/buses/search
 * Body: { from, to, date, passengers, filters, sortBy, sortOrder, paging, userLocation }
 * - from/to: { stopId | city | coords:{lat,lng} }
 * - date: ISO date string (local service timezone handled downstream)
 * - passengers: { adults, children, infants }
 * - filters: { operator, ac, sleeper, classes[], departureWindow:{start,end}, maxStops, maxDurationMin, amenities[] }
 * - sortBy: price|duration|departure|arrival|relevance; sortOrder: asc|desc
 * - paging: { page, limit }
 */
exports.searchBuses = asyncHandler(async (req, res) => {
  const {
    from,
    to,
    date,
    passengers = { adults: 1, children: 0 },
    filters = {},
    sortBy = 'relevance',
    sortOrder = 'asc',
    paging = { page: 1, limit: 20 },
    userLocation
  } = req.body || {};

  if (!from || !to || !date) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'from, to and date are required for bus search');
  }

  const page = clamp(parseInt(paging.page || 1), 1, 200);
  const limit = clamp(parseInt(paging.limit || 20), 1, 100);

  const result = await busService.search({
    from,
    to,
    date,
    passengers,
    filters,
    sortBy,
    sortOrder,
    page,
    limit
  });

  // Optionally enrich with distance to boarding if userLocation provided
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
    new ApiResponse(StatusCodes.OK, 'Bus search completed', {
      trips: enrichedTrips,
      pagination: result.pagination || { page, limit, total: enrichedTrips.length, totalPages: 1 },
      facets: result.facets || {},
      generatedAt: toISO()
    })
  );
});

/**
 * GET /api/v1/buses/:id
 * Returns full bus trip details including ordered stop_times-like structure and fare classes.
 */
exports.getBusById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const trip = await Bus.findById(id)
    .select(
      'id number name operator serviceDays validity classes amenities policies ' +
        'stops fares routeShapeRef rating reviews createdAt updatedAt'
    )
    .lean();

  if (!trip) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Bus trip not found');
  }

  // Populate stop metadata
  const stopIds = (trip.stops || []).map((s) => s.stopRefId).filter(Boolean);
  const stopsMap = stopIds.length
    ? (
        await BusStop.find({ _id: { $in: stopIds } })
          .select('name city country tz location stop_code amenities')
          .lean()
      ).reduce((acc, s) => ((acc[String(s._id)] = s), acc), {})
    : {};

  const stops = (trip.stops || [])
    .sort((a, b) => (a.seq || 0) - (b.seq || 0))
    .map((s) => {
      const meta = stopsMap[String(s.stopRefId)] || {};
      const feature = meta?.location?.coordinates
        ? {
            geoUri: `geo:${meta.location.coordinates},${meta.location.coordinates}`
          }
        : {};
      return {
        seq: s.seq,
        stopRefId: s.stopRefId,
        stop_code: meta.stop_code || null,
        name: meta.name || s.name,
        city: meta.city || null,
        country: meta.country || null,
        tz: meta.tz || null,
        arr: s.arr, // ISO 8601 with offset expected from seed/model
        dep: s.dep, // ISO 8601 with offset expected from seed/model
        platform: s.platform || s.bay || null,
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
    .json(new ApiResponse(StatusCodes.OK, 'Bus trip fetched', response));
});

/**
 * GET /api/v1/buses/:id/route
 * Returns RFC 7946 GeoJSON LineString for the bus shape and ordered stop points for overlays.
 */
exports.getBusRoute = asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Load bus with shape and stops
  const bus = await Bus.findById(id).select('id name number routeShape coordinatesGeoJSON stops').lean();
  if (!bus) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Bus trip not found');
  }

  // Build LineString geojson from stored coords or via mapService
  let line = null;
  if (bus?.coordinatesGeoJSON?.type === 'LineString') {
    line = bus.coordinatesGeoJSON; // already RFC 7946 [lng,lat]
  } else if (Array.isArray(bus?.routeShape) && bus.routeShape.length) {
    line = mapService.toLineString(bus.routeShape); // expects array of [lng,lat]
  }

  // Build stop features (points)
  const stopIds = (bus.stops || []).map((s) => s.stopRefId).filter(Boolean);
  const stopDocs = stopIds.length
    ? await BusStop.find({ _id: { $in: stopIds } })
        .select('name city country location tz stop_code')
        .lean()
    : [];
  const stopDocMap = stopDocs.reduce((acc, s) => ((acc[String(s._id)] = s), acc), {});

  const stopFeatures = (bus.stops || [])
    .sort((a, b) => (a.seq || 0) - (b.seq || 0))
    .map((s) => {
      const d = stopDocMap[String(s.stopRefId)] || {};
      const coords = d?.location?.coordinates;
      if (!coords) return null;
      return {
        type: 'Feature',
        geometry: { type: 'Point', coordinates: coords },
        properties: {
          seq: s.seq,
          stopRefId: s.stopRefId,
          name: d.name || s.name,
          stop_code: d.stop_code || null,
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
              properties: { id: bus._id, kind: 'bus_route', name: bus.name || bus.number }
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
 * GET /api/v1/buses/live/:id
 * Returns live vehicle position (if available) for tracking overlays and ETAs.
 */
exports.getLiveStatus = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const live = await busService.getLiveStatus(id); // { lat,lng,speedKph,heading,lastUpdatedISO, nextStopRefId, etaToNextISO }
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
 * GET /api/v1/buses/operators
 * Returns bus operators with counts and popular routes for filters/facets.
 */
exports.getOperators = asyncHandler(async (req, res) => {
  const cacheKey = 'bus_operators_v1';
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Operators fetched (cache)', cached));
  }

  const agg = await Bus.aggregate([
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
 * GET /api/v1/buses/:id/seatmap?fromStopId=&toStopId=&date=
 * Returns seat map and availability for a selected leg/date to power seat selection UI.
 */
exports.getSeatMap = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { fromStopId, toStopId, date } = req.query;

  if (!fromStopId || !toStopId || !date) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'fromStopId, toStopId and date are required');
  }

  const seatmap = await busService.getSeatMap({
    busId: id,
    fromStopId,
    toStopId,
    date
  }); // { layout, availableSeats[], blockedSeats[], pricingRules }

  if (!seatmap) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Seat map not available');
  }

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Seat map fetched', { ...seatmap, generatedAt: toISO() }));
});

/**
 * POST /api/v1/buses/quote
 * Body: { busId, fromStopId, toStopId, date, passengers, class, addons }
 * Returns fare quote with currency and hold expiry for checkout.
 */
exports.getFareQuote = asyncHandler(async (req, res) => {
  const { busId, fromStopId, toStopId, date, passengers, travelClass, addons } = req.body || {};

  if (!busId || !fromStopId || !toStopId || !date || !passengers) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'busId, fromStopId, toStopId, date, passengers are required');
  }

  const quote = await busService.getFareQuote({
    busId,
    fromStopId,
    toStopId,
    date,
    passengers,
    travelClass,
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
 * GET /api/v1/buses/suggest?q=&limit=
 * Suggest bus routes / headsings / operators for search bars.
 */
exports.suggest = asyncHandler(async (req, res) => {
  const { q = '', limit = 8 } = req.query;
  if (!q || String(q).trim().length < 2) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: [] }));
  }

  const lmt = clamp(parseInt(limit), 1, 20);
  const suggestions = await Bus.find({
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

  const mapped = suggestions.map((b) => ({
    id: b._id,
    label: `${b.name || b.number} · ${b.operator}`,
    from: b.stops?.[0]?.name || null,
    to: b.stops?.[b.stops.length - 1]?.name || null
  }));

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: mapped }));
});
