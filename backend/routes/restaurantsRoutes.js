// C:\flutterapp\myapp\backend\routes\restaurantsRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust path if different)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/restaurantsController.js implements these handlers)
const restaurantsController = require('../controllers/restaurantsController');

// Health check
// GET /api/v1/restaurants/health
router.get('/health', restaurantsController.health);

// List/search restaurants with filters, sorting, and pagination
// GET /api/v1/restaurants?city=&country=&cuisines=&dietary=&features=&minPrice=&maxPrice=&openNow=&sort=&page=&limit=
router.get('/', restaurantsController.getRestaurants);

// Nearby restaurants by lat/lng/radius
// GET /api/v1/restaurants/nearby?lat=&lng=&radiusKm=&limit=
router.get('/nearby', restaurantsController.getNearbyRestaurants);

// Autocomplete suggestions by name/city/country/cuisine
// GET /api/v1/restaurants/suggest?q=&limit=
router.get('/suggest', restaurantsController.suggestRestaurants);

// Trending restaurants (engagement-based)
// GET /api/v1/restaurants/trending?city=&country=&limit=
router.get('/trending', restaurantsController.getTrending);

// Facets for filters (cuisines, price buckets, dietary options, features)
// GET /api/v1/restaurants/facets?city=&country=
router.get('/facets', restaurantsController.getFacets);

// RFC 7946 FeatureCollection for map overlays
// GET /api/v1/restaurants/geojson?city=&country=&limit=
router.get('/geojson', restaurantsController.getRestaurantsGeoJSON);

// BBox query for viewport loading
// GET /api/v1/restaurants/bbox?minLng=&minLat=&maxLng=&maxLat=&limit=
router.get('/bbox', restaurantsController.getByBBox);

// Restaurant details by id or slug
// GET /api/v1/restaurants/:idOrSlug
router.get('/:idOrSlug', restaurantsController.getRestaurantByIdOrSlug);

// Menus snapshot (sections/items/prices)
// GET /api/v1/restaurants/:idOrSlug/menus
router.get('/:idOrSlug/menus', restaurantsController.getMenus);

// Availability and reservation slots (ISO 8601 date/time)
// GET /api/v1/restaurants/:idOrSlug/availability?date=YYYY-MM-DD&partySize=&time=HH:mm
router.get('/:idOrSlug/availability', restaurantsController.getAvailability);

// Create a reservation/booking (auth required)
// POST /api/v1/restaurants/:idOrSlug/book
// Body: { date, time, partySize, contact, notes?, payment? }
router.post('/:idOrSlug/book', requireAuth, restaurantsController.bookTable);

// Add a review (auth required)
// POST /api/v1/restaurants/:idOrSlug/reviews
// Body: { rating, title?, text?, photos? }
router.post('/:idOrSlug/reviews', requireAuth, restaurantsController.addReview);

// Paginated photos (official + user)
// GET /api/v1/restaurants/:idOrSlug/photos?page=&limit=
router.get('/:idOrSlug/photos', restaurantsController.getPhotos);

module.exports = router;
