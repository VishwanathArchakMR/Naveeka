// C:\flutterapp\myapp\backend\routes\hotelsRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust import path if different)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/hotelsController.js implements these handlers)
const hotelsController = require('../controllers/hotelsController');

// Health check
// GET /api/v1/hotels/health
router.get('/health', hotelsController.health);

// List/search hotels with filters, sorting, and pagination
// GET /api/v1/hotels?city=&country=&stars=&tags=&minPrice=&maxPrice=&sort=&page=&limit=
router.get('/', hotelsController.getHotels);

// Nearby hotels by lat/lng/radius
// GET /api/v1/hotels/nearby?lat=&lng=&radiusKm=&limit=
router.get('/nearby', hotelsController.getNearbyHotels);

// Autocomplete suggestions by name/brand/city/country
// GET /api/v1/hotels/suggest?q=&limit=
router.get('/suggest', hotelsController.suggestHotels);

// Trending hotels (engagement-based)
// GET /api/v1/hotels/trending?city=&country=&limit=
router.get('/trending', hotelsController.getTrending);

// Facets for filters (stars, price buckets, tags, amenities)
// GET /api/v1/hotels/facets?city=&country=
router.get('/facets', hotelsController.getFacets);

// RFC 7946 FeatureCollection for map overlays
// GET /api/v1/hotels/geojson?city=&country=&limit=
router.get('/geojson', hotelsController.getHotelsGeoJSON);

// BBox query for viewport loading
// GET /api/v1/hotels/bbox?minLng=&minLat=&maxLng=&maxLat=&limit=
router.get('/bbox', hotelsController.getByBBox);

// Hotel details by id or slug
// GET /api/v1/hotels/:idOrSlug
router.get('/:idOrSlug', hotelsController.getHotelByIdOrSlug);

// Availability for dates/guests/rooms (ISO 8601 dates)
// GET /api/v1/hotels/:idOrSlug/availability?checkIn=YYYY-MM-DD&checkOut=YYYY-MM-DD&adults=&children=&rooms=
router.get('/:idOrSlug/availability', hotelsController.getAvailability);

// Room list and rate plans snapshot
// GET /api/v1/hotels/:idOrSlug/rooms?checkIn=YYYY-MM-DD&checkOut=YYYY-MM-DD&adults=&children=
router.get('/:idOrSlug/rooms', hotelsController.getRooms);

// Price/hold quote for selected room(s) with expiry
// POST /api/v1/hotels/:idOrSlug/quote
// Body: { checkIn, checkOut, guests, rooms: [...], ratePlanId?, currency? }
router.post('/:idOrSlug/quote', hotelsController.getQuote);

// Create a booking (auth required)
// POST /api/v1/hotels/:idOrSlug/book
// Body: { offer|quote, contact, guests, payment }
router.post('/:idOrSlug/book', requireAuth, hotelsController.bookHotel);

// Add a review (auth required, optionally after completed stay)
// POST /api/v1/hotels/:idOrSlug/reviews
// Body: { rating, title?, text?, photos? }
router.post('/:idOrSlug/reviews', requireAuth, hotelsController.addReview);

// Paginated photos (official + user)
// GET /api/v1/hotels/:idOrSlug/photos?page=&limit=
router.get('/:idOrSlug/photos', hotelsController.getPhotos);

module.exports = router;
