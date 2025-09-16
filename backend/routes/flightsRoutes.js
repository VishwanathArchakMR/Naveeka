// C:\flutterapp\myapp\backend\routes\flightsRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust path if different)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/flightsController.js implements these handlers)
const flightsController = require('../controllers/flightsController');

// Health check
// GET /api/v1/flights/health
router.get('/health', flightsController.health);

// Search flights (supports ONE_WAY | ROUND_TRIP | MULTI_CITY)
// POST /api/v1/flights/search
// Body: { tripType, slices: [{ origin:{iata}, destination:{iata}, departureISO }], pax:{adt,cnn,inf}, cabin, maxStops, sort }
router.post('/search', flightsController.searchFlights);

// Autocomplete suggestions (airlines, airports, routes)
// GET /api/v1/flights/suggest?q=&types=airport,airline,route&limit=
router.get('/suggest', flightsController.suggest);

// Supported airlines list (code -> name mapping/cache)
// GET /api/v1/flights/airlines
router.get('/airlines', flightsController.getAirlines);

// Price re-check and quote lock/expiry (reprice)
// POST /api/v1/flights/quote
// Body: { offerId | segments[], travelers[], ancillaries? }
router.post('/quote', flightsController.getQuote);

// Create a booking from a quoted offer (auth required)
// POST /api/v1/flights/book
// Body: { offerId | pricedOffer, contact, travelers, payment }
router.post('/book', requireAuth, flightsController.bookFlight);

// Flight offer/itinerary details by id (cached result)
// GET /api/v1/flights/:id
router.get('/:id', flightsController.getFlightById);

// Route geometry as RFC 7946 FeatureCollection (itinerary + segment LineStrings)
// GET /api/v1/flights/:id/route
router.get('/:id/route', flightsController.getFlightRoute);

// Live status lookup by carrier/number/date (ISO 8601 date)
// GET /api/v1/flights/status/:carrier/:number?date=YYYY-MM-DD
router.get('/status/:carrier/:number', flightsController.getLiveStatus);

module.exports = router;
