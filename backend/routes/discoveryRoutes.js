// C:\flutterapp\myapp\backend\routes\discoveryRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust path if different)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/discoveryController.js implements these handlers)
const discoveryController = require('../controllers/discoveryController');

// Health check
// GET /api/v1/discovery/health
router.get('/health', discoveryController.health);

// Personalized feed (requires auth) with cursor pagination
// GET /api/v1/discovery/feed?cursor=&limit=&lat=&lng=&interests=beach,food
router.get('/feed', requireAuth, discoveryController.getFeed);

// Trending across entity types (trails, activities, restaurants, hotels, etc.)
// GET /api/v1/discovery/trending?type=&region=&limit=
router.get('/trending', discoveryController.getTrending);

// Nearby discovery around a coordinate (mixed entities)
// GET /api/v1/discovery/nearby?lat=&lng=&radiusKm=&limit=&types=restaurant,activity,trail
router.get('/nearby', discoveryController.getNearby);

// Free-text search across entities for discovery
// GET /api/v1/discovery/search?q=&types=&city=&country=&limit=&page=
router.get('/search', discoveryController.search);

// Autocomplete suggestions for discovery search bars
// GET /api/v1/discovery/suggest?q=&types=&limit=
router.get('/suggest', discoveryController.suggest);

// Curated collections list (editorial/algorithmic)
// GET /api/v1/discovery/collections?limit=&cursor=
router.get('/collections', discoveryController.getCollections);

// Single collection detail
// GET /api/v1/discovery/collections/:id
router.get('/collections/:id', discoveryController.getCollectionById);

// Highlights and seasonal picks (e.g., “Monsoon Treks”, “Winter Escapes”)
// GET /api/v1/discovery/highlights?region=&season=&limit=
router.get('/highlights', discoveryController.getHighlights);

// Deals across supported entity types (hotels, activities, cabs partners, etc.)
// GET /api/v1/discovery/deals?type=&region=&limit=
router.get('/deals', discoveryController.getDeals);

// Editorial stories for discovery feed
// GET /api/v1/discovery/stories?limit=&cursor=
router.get('/stories', discoveryController.getStories);

// Travel guides (city/country/region guides)
// GET /api/v1/discovery/guides?region=&limit=&cursor=
router.get('/guides', discoveryController.getGuides);

module.exports = router;
