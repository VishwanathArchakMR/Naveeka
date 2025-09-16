// C:\flutterapp\myapp\backend\routes\busStopsRoutes.js

const express = require('express');
const router = express.Router();

// Controller (ensure controllers/busStopsController.js implements these handlers)
const busStopsController = require('../controllers/busStopsController');

// List bus stops with filters/pagination/sorting
// GET /api/v1/bus-stops
router.get('/', busStopsController.getBusStops);

// Nearby bus stops by lat/lng/radius
// GET /api/v1/bus-stops/nearby
router.get('/nearby', busStopsController.getNearbyBusStops);

// Autocomplete suggestions by name/city/country/stop_code
// GET /api/v1/bus-stops/suggest
router.get('/suggest', busStopsController.suggestBusStops);

// RFC 7946 FeatureCollection for map overlays
// GET /api/v1/bus-stops/geojson
router.get('/geojson', busStopsController.getBusStopsGeoJSON);

// BBox query for viewport loading
// GET /api/v1/bus-stops/bbox
router.get('/bbox', busStopsController.getByBBox);

// Bus stop details by Mongo id or public stop_code
// GET /api/v1/bus-stops/:idOrCode
router.get('/:idOrCode', busStopsController.getBusStopByIdOrCode);

// Serving buses for a given stop
// GET /api/v1/bus-stops/:id/serving-buses
router.get('/:id/serving-buses', busStopsController.getServingBuses);

module.exports = router;
