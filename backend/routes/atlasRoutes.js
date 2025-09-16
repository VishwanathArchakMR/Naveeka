// C:\flutterapp\myapp\backend\routes\atlasRoutes.js

const express = require('express');
const router = express.Router();

// Controller (ensure controllers/atlasController.js implements these handlers)
const atlasController = require('../controllers/atlasController');

// Health check for atlas aggregation
// GET /api/v1/atlas/health
router.get('/health', atlasController.health);

// List available atlas layers and fields used by the client
// GET /api/v1/atlas/layers
router.get('/layers', atlasController.listLayers);

// Aggregate RFC 7946 FeatureCollection across layers with optional filters
// GET /api/v1/atlas/geojson?layers=hotels,restaurants,trails,airports,train_stations,bus_stops,activities,places&limit=2000
// Optional filters: city, country, tags, rating, priceRange, difficulty, openNow, etc.
router.get('/geojson', atlasController.getGeoJSON);

// Viewport/BBox loading for current map view (returns FeatureCollection)
// GET /api/v1/atlas/viewport?minLng=&minLat=&maxLng=&maxLat=&layers=&limit=
// Optional: densityHint=low|med|high for server-side thinning
router.get('/viewport', atlasController.getByViewport);

// Nearby search around a coordinate across multiple layers
// GET /api/v1/atlas/nearby?lat=&lng=&radiusKm=&layers=&limit=
// Optional: sort=distance|popularity|rating
router.get('/nearby', atlasController.getNearby);

// Free-text search across layers for names/tags (returns lightweight features)
// GET /api/v1/atlas/search?q=&layers=&city=&country=&limit=
router.get('/search', atlasController.search);

// Fetch a single feature as RFC 7946 GeoJSON by type and id
// GET /api/v1/atlas/feature/:type/:id
// type in: hotel|restaurant|trail|airport|train_station|bus_stop|activity|place
router.get('/feature/:type/:id', atlasController.getFeatureById);

module.exports = router;
