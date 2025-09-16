// C:\flutterapp\myapp\backend\routes\trailsRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust path if different)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/trailsController.js implements these handlers)
const trailsController = require('../controllers/trailsController');

// Health check
// GET /api/v1/trails/health
router.get('/health', trailsController.health);

// List/search trails with filters, sorting, and pagination
// GET /api/v1/trails?city=&country=&region=&difficulty=&tags=&lengthMin=&lengthMax=&elevGainMin=&elevGainMax=&openNow=&sort=&page=&limit=
router.get('/', trailsController.getTrails);

// Nearby trails by lat/lng/radius
// GET /api/v1/trails/nearby?lat=&lng=&radiusKm=&limit=
router.get('/nearby', trailsController.getNearbyTrails);

// Autocomplete suggestions by name/city/country/region/tags
// GET /api/v1/trails/suggest?q=&limit=
router.get('/suggest', trailsController.suggestTrails);

// Trending trails (engagement-based)
// GET /api/v1/trails/trending?region=&limit=
router.get('/trending', trailsController.getTrending);

// Facets for filters (difficulty, length, elevation, tags/region)
// GET /api/v1/trails/facets?region=&country=
router.get('/facets', trailsController.getFacets);

// RFC 7946 FeatureCollection for map overlays
// GET /api/v1/trails/geojson?region=&country=&limit=
router.get('/geojson', trailsController.getTrailsGeoJSON);

// BBox query for viewport loading
// GET /api/v1/trails/bbox?minLng=&minLat=&maxLng=&maxLat=&limit=
router.get('/bbox', trailsController.getByBBox);

// Trail details by id or slug
// GET /api/v1/trails/:idOrSlug
router.get('/:idOrSlug', trailsController.getTrailByIdOrSlug);

// Route geometry as RFC 7946 FeatureCollection (LineString/MultiLineString + waypoints)
// GET /api/v1/trails/:idOrSlug/route
router.get('/:idOrSlug/route', trailsController.getTrailRoute);

// Elevation profile (distance vs elevation)
// GET /api/v1/trails/:idOrSlug/elevation
router.get('/:idOrSlug/elevation', trailsController.getElevationProfile);

// Conditions and seasons (open/closures, seasonal notes)
// GET /api/v1/trails/:idOrSlug/conditions
router.get('/:idOrSlug/conditions', trailsController.getConditions);

// Mark a trail as completed (logs to history, updates completion count)
// POST /api/v1/trails/:idOrSlug/complete
// Body: { occurredAt?: ISOString, distanceKm?: number, durationMin?: number, notes?: string }
router.post('/:idOrSlug/complete', requireAuth, trailsController.markCompleted);

// Add a review (auth required)
// POST /api/v1/trails/:idOrSlug/reviews
// Body: { rating, title?, text?, photos? }
router.post('/:idOrSlug/reviews', requireAuth, trailsController.addReview);

// Paginated photos (official + user)
// GET /api/v1/trails/:idOrSlug/photos?page=&limit=
router.get('/:idOrSlug/photos', trailsController.getPhotos);

// Export route as GPX
// GET /api/v1/trails/:idOrSlug/export/gpx
router.get('/:idOrSlug/export/gpx', trailsController.exportGPX);

// Export route as GeoJSON FeatureCollection
// GET /api/v1/trails/:idOrSlug/export/geojson
router.get('/:idOrSlug/export/geojson', trailsController.exportGeoJSON);

module.exports = router;
