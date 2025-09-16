// C:\flutterapp\myapp\backend\routes\airportsRoutes.js

const express = require('express');
const router = express.Router();

// Controller (ensure controllers/airportsController.js implements these handlers)
const airportsController = require('../controllers/airportsController');

// List with filters, pagination, sorting
// GET /api/v1/airports
router.get('/', airportsController.getAirports);

// Nearby by lat/lng/radius
// GET /api/v1/airports/nearby
router.get('/nearby', airportsController.getNearbyAirports);

// Autocomplete suggestions by name/city/country/code
// GET /api/v1/airports/suggest
router.get('/suggest', airportsController.suggestAirports);

// Trending airports (engagement-based)
// GET /api/v1/airports/trending
router.get('/trending', airportsController.getTrending);

// Facets for filters (country, city, etc.)
// GET /api/v1/airports/facets
router.get('/facets', airportsController.getFacets);

// RFC 7946 FeatureCollection for map overlays
// GET /api/v1/airports/geojson
router.get('/geojson', airportsController.getAirportsGeoJSON);

// BBox query for viewport loading
// GET /api/v1/airports/bbox
router.get('/bbox', airportsController.getByBBox);

// Airport details by Mongo id or IATA/ICAO code
// GET /api/v1/airports/:idOrCode
router.get('/:idOrCode', airportsController.getAirportByIdOrCode);

module.exports = router;
