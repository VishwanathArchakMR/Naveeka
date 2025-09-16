// C:\flutterapp\myapp\backend\routes\activitiesRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust the path/name if different in your project)
const { requireAuth } = require('../middleware/auth');

// Controller (ensure these handlers exist in controllers/activitiesController.js)
const activitiesController = require('../controllers/activitiesController');

// List with filters/sort/pagination
// GET /api/v1/activities
router.get('/', activitiesController.getActivities);

// Nearby by lat/lng/radius
// GET /api/v1/activities/nearby
router.get('/nearby', activitiesController.getNearbyActivities);

// Autocomplete suggestions
// GET /api/v1/activities/suggest
router.get('/suggest', activitiesController.suggestActivities);

// Trending activities
// GET /api/v1/activities/trending
router.get('/trending', activitiesController.getTrending);

// Facets for filters (categories/tags/price/rating buckets)
// GET /api/v1/activities/facets
router.get('/facets', activitiesController.getFacets);

// RFC 7946 FeatureCollection for map overlays
// GET /api/v1/activities/geojson
router.get('/geojson', activitiesController.getActivitiesGeoJSON);

// Activity details with optional recent reviews and geo link
// GET /api/v1/activities/:id
router.get('/:id', activitiesController.getActivityById);

// Availability and slots (ISO 8601 times)
// GET /api/v1/activities/:id/availability
router.get('/:id/availability', activitiesController.getAvailability);

// Create a booking (auth required)
// POST /api/v1/activities/:id/book
router.post('/:id/book', requireAuth, activitiesController.bookActivity);

// Add a review (auth required, optionally after completed booking)
// POST /api/v1/activities/:id/reviews
router.post('/:id/reviews', requireAuth, activitiesController.addReview);

// Paginated photos (official + user)
// GET /api/v1/activities/:id/photos
router.get('/:id/photos', activitiesController.getPhotos);

module.exports = router;
