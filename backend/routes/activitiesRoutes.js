// C:\app\Naveeka\backend\routes\activitiesRoutes.js

const express = require('express');
const router = express.Router();

const asyncHandler = require('../utils/asyncHandler');
const { requireAuth } = require('../middleware/auth');

// Import controller handlers as named exports.
// Ensure these exact names are exported from ../controllers/activitiesController.js
const {
  getActivities,
  getNearbyActivities,
  suggestActivities,
  getTrending,
  getFacets,
  getActivitiesGeoJSON,
  getActivityById,
  getAvailability,
  bookActivity,
  addReview,
  getPhotos,
} = require('../controllers/activitiesController');

// Fail fast if any dependency is missing/misnamed to avoid undefined callbacks.
const guards = {
  requireAuth,
  getActivities,
  getNearbyActivities,
  suggestActivities,
  getTrending,
  getFacets,
  getActivitiesGeoJSON,
  getActivityById,
  getAvailability,
  bookActivity,
  addReview,
  getPhotos,
};

Object.entries(guards).forEach(([name, fn]) => {
  if (typeof fn !== 'function') {
    throw new Error(`${name} is undefined or not a function`);
  }
});

// Routes

// List with filters/sort/pagination
// GET /api/v1/activities
router.get('/', asyncHandler(getActivities));

// Nearby by lat/lng/radius
// GET /api/v1/activities/nearby
router.get('/nearby', asyncHandler(getNearbyActivities));

// Autocomplete suggestions
// GET /api/v1/activities/suggest
router.get('/suggest', asyncHandler(suggestActivities));

// Trending activities
// GET /api/v1/activities/trending
router.get('/trending', asyncHandler(getTrending));

// Facets for filters (categories/tags/price/rating buckets)
// GET /api/v1/activities/facets
router.get('/facets', asyncHandler(getFacets));

// RFC 7946 FeatureCollection for map overlays
// GET /api/v1/activities/geojson
router.get('/geojson', asyncHandler(getActivitiesGeoJSON));

// Activity details
// GET /api/v1/activities/:id
router.get('/:id', asyncHandler(getActivityById));

// Availability and slots (ISO 8601 times)
// GET /api/v1/activities/:id/availability
router.get('/:id/availability', asyncHandler(getAvailability));

// Create a booking (auth required)
// POST /api/v1/activities/:id/book
router.post('/:id/book', requireAuth, asyncHandler(bookActivity));

// Add a review (auth required)
// POST /api/v1/activities/:id/reviews
router.post('/:id/reviews', requireAuth, asyncHandler(addReview));

// Paginated photos (official + user)
// GET /api/v1/activities/:id/photos
router.get('/:id/photos', asyncHandler(getPhotos));

module.exports = router;
