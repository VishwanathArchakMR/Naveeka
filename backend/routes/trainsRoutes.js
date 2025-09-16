// C:\flutterapp\myapp\backend\routes\trainsRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust path if different)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/trainsController.js implements these handlers)
const trainsController = require('../controllers/trainsController');

// Health check
// GET /api/v1/trains/health
router.get('/health', trainsController.health);

// Search trains (POST to allow complex payload: multi-legs, filters)
// Body: { originStationId|code, destinationStationId|code, date: YYYY-MM-DD, time?, passengers?, classes?, operators?, sort?, filters? }
// POST /api/v1/trains/search
router.post('/search', trainsController.searchTrains);

// Autocomplete suggestions (trains, stations, routes)
// GET /api/v1/trains/suggest?q=&types=train,station,route&limit=
router.get('/suggest', trainsController.suggest);

// Operators list and metadata
// GET /api/v1/trains/operators
router.get('/operators', trainsController.getOperators);

// Trending trains (engagement-based)
// GET /api/v1/trains/trending?region=&limit=
router.get('/trending', trainsController.getTrending);

// Multi-entity RFC 7946 FeatureCollection for map overlays (routes + stations summary)
// GET /api/v1/trains/geojson?region=&limit=
router.get('/geojson', trainsController.getTrainsGeoJSON);

// BBox query for viewport loading (LineStrings clipped server-side if needed)
// GET /api/v1/trains/bbox?minLng=&minLat=&maxLng=&maxLat=&limit=
router.get('/bbox', trainsController.getByBBox);

// Train details by id (includes classes, serviceDays, validity, review aggregates)
// GET /api/v1/trains/:id
router.get('/:id', trainsController.getTrainById);

// Ordered stops and basic timetable (GTFS-like stop_times semantics)
// GET /api/v1/trains/:id/stops
router.get('/:id/stops', trainsController.getStops);

// Full schedule for a specific date (handles service exceptions/validity)
// GET /api/v1/trains/:id/schedule?date=YYYY-MM-DD
router.get('/:id/schedule', trainsController.getSchedule);

// Available classes and fare bands
// GET /api/v1/trains/:id/fares
router.get('/:id/fares', trainsController.getFares);

// Route geometry as RFC 7946 FeatureCollection (LineString + station points)
// GET /api/v1/trains/:id/route
router.get('/:id/route', trainsController.getTrainRoute);

// Live status lookup by operator/number/date (ISO 8601 date)
// GET /api/v1/trains/status/:operator/:number?date=YYYY-MM-DD
router.get('/status/:operator/:number', trainsController.getLiveStatus);

// Seat map for a class/date/coach (if available)
// GET /api/v1/trains/:id/seatmap?date=YYYY-MM-DD&classCode=&coach=
router.get('/:id/seatmap', trainsController.getSeatMap);

// Availability and waitlist info
// GET /api/v1/trains/:id/availability?date=YYYY-MM-DD&classCode=&quota=
router.get('/:id/availability', trainsController.getAvailability);

// Fare quote (pricing, currency, hold expiry)
// POST /api/v1/trains/quote
// Body: { trainId, date, classCode, originStopSeq|stationId, destinationStopSeq|stationId, passengers, preferences? }
router.post('/quote', trainsController.getQuote);

// Create a booking (auth required)
// POST /api/v1/trains/:id/book
// Body: { quote|pricedOffer, contact, passengers, payment }
router.post('/:id/book', requireAuth, trainsController.bookTrain);

// Convenience: trains serving a station (delegates to stops index)
// GET /api/v1/trains/serving-station/:stationId?date=YYYY-MM-DD
router.get('/serving-station/:stationId', trainsController.getTrainsByStation);

module.exports = router;
