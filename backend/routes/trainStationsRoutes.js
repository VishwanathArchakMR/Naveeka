// C:\flutterapp\myapp\backend\routes\trainStationsRoutes.js

const express = require('express');
const router = express.Router();

// Controller (ensure controllers/trainStationsController.js implements these)
const stationsController = require('../controllers/trainStationsController');

// Health check
// GET /api/v1/train-stations/health
router.get('/health', stationsController.health);

// List/search stations with filters, sorting, and pagination
// GET /api/v1/train-stations?city=&country=&q=&sort=&page=&limit=
router.get('/', stationsController.getStations);

// Nearby stations by lat/lng/radius
// GET /api/v1/train-stations/nearby?lat=&lng=&radiusKm=&limit=
router.get('/nearby', stationsController.getNearbyStations);

// Autocomplete suggestions by name/city/country/station_code
// GET /api/v1/train-stations/suggest?q=&limit=
router.get('/suggest', stationsController.suggestStations);

// Trending stations (engagement-based)
// GET /api/v1/train-stations/trending?region=&limit=
router.get('/trending', stationsController.getTrending);

// Facets for filters (country, city, amenities, etc.)
// GET /api/v1/train-stations/facets?city=&country=
router.get('/facets', stationsController.getFacets);

// RFC 7946 FeatureCollection for map overlays
// GET /api/v1/train-stations/geojson?city=&country=&limit=
router.get('/geojson', stationsController.getStationsGeoJSON);

// BBox query for viewport loading
// GET /api/v1/train-stations/bbox?minLng=&minLat=&maxLng=&maxLat=&limit=
router.get('/bbox', stationsController.getByBBox);

// Station details by Mongo id or public station_code
// GET /api/v1/train-stations/:idOrCode
router.get('/:idOrCode', stationsController.getStationByIdOrCode);

// Trains serving a station (for a specific date if provided)
// GET /api/v1/train-stations/:id/serving-trains?date=YYYY-MM-DD
router.get('/:id/serving-trains', stationsController.getServingTrains);

module.exports = router;
