// C:\app\Naveeka\backend\routes\airportRoutes.js

const express = require('express');
const router = express.Router();

const asyncHandler = require('../utils/asyncHandler');

// Import controller handlers as named exports.
// Ensure these exact names are exported from ../controllers/airportsController.js
const {
  getAirports,
  getNearbyAirports,
  suggestAirports,
  getTrending,
  getFacets,
  getAirportsGeoJSON,
  getByBBox,
  getAirportByIdOrCode,
} = require('../controllers/airportsController');

// Fail fast if any handler is missing/misnamed to avoid undefined callbacks.
const guards = {
  getAirports,
  getNearbyAirports,
  suggestAirports,
  getTrending,
  getFacets,
  getAirportsGeoJSON,
  getByBBox,
  getAirportByIdOrCode,
};

Object.entries(guards).forEach(([name, fn]) => {
  if (typeof fn !== 'function') {
    throw new Error(`airportsController.${name} is undefined or not a function`);
  }
});

// Routes

// List with filters, pagination, sorting
// GET /api/airports
router.get('/', asyncHandler(getAirports));

// Nearby by lat/lng/radius
// GET /api/airports/nearby
router.get('/nearby', asyncHandler(getNearbyAirports));

// Autocomplete suggestions by name/city/country/code
// GET /api/airports/suggest
router.get('/suggest', asyncHandler(suggestAirports));

// Trending airports (engagement-based)
// GET /api/airports/trending
router.get('/trending', asyncHandler(getTrending));

// Facets for filters (country, city, etc.)
// GET /api/airports/facets
router.get('/facets', asyncHandler(getFacets));

// RFC 7946 FeatureCollection for map overlays
// GET /api/airports/geojson
router.get('/geojson', asyncHandler(getAirportsGeoJSON));

// BBox query for viewport loading
// GET /api/airports/bbox
router.get('/bbox', asyncHandler(getByBBox));

// Airport details by Mongo id or IATA/ICAO code
// GET /api/airports/:idOrCode
router.get('/:idOrCode', asyncHandler(getAirportByIdOrCode));

module.exports = router;
