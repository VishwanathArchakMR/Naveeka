// C:\flutterapp\myapp\backend\routes\busesRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust path if different)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/busesController.js implements these handlers)
const busesController = require('../controllers/busesController');

// Search buses (POST to allow complex payloads)
// POST /api/v1/buses/search
router.post('/search', busesController.searchBuses);

// Autocomplete suggestions
// GET /api/v1/buses/suggest
router.get('/suggest', busesController.suggestBuses);

// Operators overview (cached list, counts, fare ranges)
// GET /api/v1/buses/operators
router.get('/operators', busesController.getOperators);

// Trending buses (engagement-based)
// GET /api/v1/buses/trending
router.get('/trending', busesController.getTrending);

// Multi-entity RFC 7946 FeatureCollection for map overlays
// GET /api/v1/buses/geojson
router.get('/geojson', busesController.getBusesGeoJSON);

// Live bus status by trip id (position/ETA)
// GET /api/v1/buses/live/:id
router.get('/live/:id', busesController.getLiveStatus);

// Seat map and availability for a leg/date/class
// GET /api/v1/buses/:id/seatmap
router.get('/:id/seatmap', busesController.getSeatMap);

// Fare quote (pricing, currency, hold expiry)
// POST /api/v1/buses/quote
router.post('/quote', busesController.getFareQuote);

// Create a booking (auth required)
// POST /api/v1/buses/:id/book
router.post('/:id/book', requireAuth, busesController.bookSeat);

// Bus details by id with ordered stops
// GET /api/v1/buses/:id
router.get('/:id', busesController.getBusById);

// Route geometry as RFC 7946 FeatureCollection (LineString + stops)
// GET /api/v1/buses/:id/route
router.get('/:id/route', busesController.getBusRoute);

module.exports = router;
