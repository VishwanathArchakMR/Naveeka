// C:\flutterapp\myapp\backend\controllers\flightsController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const Flight = require('../models/Flight');          // priced itineraries (optional cache/store)
const Airport = require('../models/Airport');        // airport meta for map/selector enrichment

// Services (per upgrade plan)
const flightsService = require('../services/flightService');        // search, price, quote, booking, status
const cacheService = require('../services/cacheService');           // optional Redis
const mapService = require('../services/mapService');               // RFC 7946 helpers (lines, features)
const locationService = require('../services/locationService');     // distance/haversine if needed

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601 UTC
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const isStr = (v) => typeof v === 'string' && v.trim().length > 0;

// POST /api/v1/flights/search
// Body: { origin, destination, departDate, returnDate?, cabinClass?, pax:{adults,children,infants}, nonStop?, maxStops?, airlines?, sortBy?, sortOrder?, page?, limit? }
// origin/destination can be IATA (preferred) or ICAO; service will resolve via Airport catalog.
exports.searchFlights = asyncHandler(async (req, res) => {
  const {
    origin,
    destination,
    departDate,
    returnDate,
    cabinClass = 'ECONOMY',
    pax = { adults: 1, children: 0, infants: 0 },
    nonStop,
    maxStops,
    airlines = [],
    sortBy = 'price',
    sortOrder = 'asc',
    page = 1,
    limit = 20
  } = req.body || {};

  if (!isStr(origin) || !isStr(destination) || !isStr(departDate)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'origin, destination and departDate are required'); 
  }

  const p = clamp(parseInt(page || 1), 1, 100);
  const l = clamp(parseInt(limit || 20), 1, 100);

  const result = await flightsService.search({
    origin,
    destination,
    departDate,
    returnDate,
    cabinClass,
    pax,
    nonStop,
    maxStops,
    airlines,
    sortBy,
    sortOrder,
    page: p,
    limit: l
  }); // { itineraries:[], pagination:{page,limit,total,totalPages}, facets:{}, processingTimeMs }

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Flight search completed', {
      ...result,
      generatedAt: toISO()
    })
  );
});

// GET /api/v1/flights/:id
// Full itinerary details: segments, legs, fare rules, baggage, and mapped airports (IATA/ICAO aware)
exports.getFlightById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Prefer pulling from provider via service; fall back to DB cache if present
  const itinerary = await flightsService.getById(id);
  if (!itinerary) {
    const cached = await Flight.findById(id).lean();
    if (!cached) throw new ApiError(StatusCodes.NOT_FOUND, 'Flight not found');
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Flight fetched', { itinerary: cached, generatedAt: toISO() }));
  }

  // Enrich airports (map + selector)
  const airportCodes = new Set();
  (itinerary.segments || []).forEach((s) => {
    if (s.origin?.iata) airportCodes.add(s.origin.iata);
    if (s.destination?.iata) airportCodes.add(s.destination.iata);
    if (s.origin?.icao) airportCodes.add(s.origin.icao);
    if (s.destination?.icao) airportCodes.add(s.destination.icao);
  });

  // Try to resolve by IATA first, then ICAO
  const codes = Array.from(airportCodes);
  const airports = await Airport.find({
    $or: [
      { iata: { $in: codes } },
      { icao: { $in: codes } }
    ]
  }).select('name iata icao city country tz location').lean();

  const airportIndex = {};
  airports.forEach((a) => {
    if (a.iata) airportIndex[a.iata] = a;
    if (a.icao) airportIndex[a.icao] = a;
  });

  // Attach geoUri for airports
  (itinerary.segments || []).forEach((s) => {
    const o = airportIndex[s.origin?.iata] || airportIndex[s.origin?.icao];
    const d = airportIndex[s.destination?.iata] || airportIndex[s.destination?.icao];
    if (o?.location?.coordinates) {
      const [lng, lat] = o.location.coordinates;
      s.origin.geoUri = `geo:${lat},${lng}`;
    }
    if (d?.location?.coordinates) {
      const [lng, lat] = d.location.coordinates;
      s.destination.geoUri = `geo:${lat},${lng}`;
    }
  });

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Flight fetched', { itinerary, generatedAt: toISO() }));
});

// POST /api/v1/flights/quote
// Body: { itineraryId or pricedOffer, ancillaries?, coupon? } -> returns priced breakdown with currency and expiry (ISO)
exports.getFareQuote = asyncHandler(async (req, res) => {
  const { itineraryId, pricedOffer, ancillaries, coupon } = req.body || {};
  if (!itineraryId && !pricedOffer) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'itineraryId or pricedOffer is required');
  }

  const quote = await flightsService.getFareQuote({ itineraryId, pricedOffer, ancillaries, coupon }); 
  // { currency, base, taxes, fees, total, fareFamily, rules, expiresAtISO }

  if (!quote) throw new ApiError(StatusCodes.NOT_FOUND, 'Quote not available');

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Fare quote generated', { ...quote, generatedAt: toISO() }));
});

// POST /api/v1/flights/book
// Body: { quoteId or pricedOffer, travelers[], contact, paymentMethod, seats? } -> returns booking record and payment info
exports.bookFlight = asyncHandler(async (req, res) => {
  const { quoteId, pricedOffer, travelers, contact, paymentMethod, seats } = req.body || {};
  if (!quoteId && !pricedOffer) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'quoteId or pricedOffer is required');
  }

  const booking = await flightsService.createBooking({ quoteId, pricedOffer, travelers, contact, paymentMethod, seats, userId: req.user?.id }); 
  // { bookingId, pnr, status, payment:{paymentUrl?,expiresAtISO?}, itinerary }

  if (!booking) throw new ApiError(StatusCodes.INTERNAL_SERVER_ERROR, 'Failed to create booking');

  return res
    .status(StatusCodes.CREATED)
    .json(new ApiResponse(StatusCodes.CREATED, 'Flight booked', { ...booking, generatedAt: toISO() }));
});

// GET /api/v1/flights/status?flightNumber=XX123&date=YYYY-MM-DD
// Live/operational status for a given flight and date
exports.getFlightStatus = asyncHandler(async (req, res) => {
  const { flightNumber, date } = req.query;
  if (!isStr(flightNumber) || !isStr(date)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'flightNumber and date are required');
  }

  const status = await flightsService.getStatus({ flightNumber, date }); 
  // { flightNumber, date, status, departure:{schedISO,estISO,gate,terminal}, arrival:{schedISO,estISO,gate,terminal}, aircraft, operational }

  if (!status) throw new ApiError(StatusCodes.NOT_FOUND, 'Status not available');

  return res
    .status(StatusCodes.OK)
    .json(new ApiResponse(StatusCodes.OK, 'Flight status fetched', { ...status, generatedAt: toISO() }));
});

// GET /api/v1/flights/:id/route
// Returns RFC 7946 FeatureCollection: LineString path (if available) plus origin/destination points for the flight route map.
exports.getFlightRoute = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const itinerary = await flightsService.getById(id);
  if (!itinerary || !Array.isArray(itinerary.segments) || itinerary.segments.length === 0) {
    throw new ApiError(StatusCodes.NOT_FOUND, 'Itinerary not found');
  }

  // Build points per segment and an approximate polyline if provided by provider
  const features = [];

  // Add origin/destination airport points
  for (const seg of itinerary.segments) {
    const originMeta = await Airport.findOne({
      $or: [{ iata: seg.origin?.iata }, { icao: seg.origin?.icao }]
    }).select('name iata icao city country tz location').lean();

    const destMeta = await Airport.findOne({
      $or: [{ iata: seg.destination?.iata }, { icao: seg.destination?.icao }]
    }).select('name iata icao city country tz location').lean();

    if (originMeta?.location?.coordinates) {
      features.push({
        type: 'Feature',
        geometry: { type: 'Point', coordinates: originMeta.location.coordinates },
        properties: {
          kind: 'airport_origin',
          name: originMeta.name,
          iata: originMeta.iata || null,
          icao: originMeta.icao || null,
          city: originMeta.city || null,
          country: originMeta.country || null,
          tz: originMeta.tz || null,
          geo: `geo:${originMeta.location.coordinates},${originMeta.location.coordinates}`
        }
      });
    }
    if (destMeta?.location?.coordinates) {
      features.push({
        type: 'Feature',
        geometry: { type: 'Point', coordinates: destMeta.location.coordinates },
        properties: {
          kind: 'airport_destination',
          name: destMeta.name,
          iata: destMeta.iata || null,
          icao: destMeta.icao || null,
          city: destMeta.city || null,
          country: destMeta.country || null,
          tz: destMeta.tz || null,
          geo: `geo:${destMeta.location.coordinates},${destMeta.location.coordinates}`
        }
      });
    }

    // If provider supplies flight path polyline coords ([lng,lat] array), add LineString
    if (Array.isArray(seg.path?.coordinates) && seg.path.coordinates.length > 1) {
      features.push({
        type: 'Feature',
        geometry: {
          type: 'LineString',
          coordinates: seg.path.coordinates // must be [lng,lat]
        },
        properties: {
          kind: 'flight_path',
          flightNumber: seg.flightNumber,
          carrier: seg.carrier,
          segmentId: seg.id
        }
      });
    }
  }

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});

// POST /api/v1/flights/price-watch
// Body: { origin, destination, departDate, returnDate?, cabinClass?, thresholdTotal, email? } -> sets/updates price alert
exports.createPriceWatch = asyncHandler(async (req, res) => {
  const { origin, destination, departDate, returnDate, cabinClass, thresholdTotal, email } = req.body || {};
  if (!isStr(origin) || !isStr(destination) || !isStr(departDate) || !thresholdTotal) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'origin, destination, departDate and thresholdTotal are required');
  }

  const watch = await flightsService.createPriceWatch({
    origin,
    destination,
    departDate,
    returnDate,
    cabinClass,
    thresholdTotal,
    email,
    userId: req.user?.id
  });

  return res
    .status(StatusCodes.CREATED)
    .json(new ApiResponse(StatusCodes.CREATED, 'Price watch created', { ...watch, generatedAt: toISO() }));
});
