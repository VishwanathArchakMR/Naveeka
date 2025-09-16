// C:\flutterapp\myapp\backend\routes\favoritesRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (favorites are user-scoped)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/favoritesController.js implements these handlers)
const favoritesController = require('../controllers/favoritesController');

// Health check
// GET /api/v1/favorites/health
router.get('/health', favoritesController.health);

// List favorites with filters and pagination
// GET /api/v1/favorites?entityType=&tags=&archived=&hidden=&page=&limit=
router.get('/', requireAuth, favoritesController.getFavorites);

// Check if an entity is favorited (idempotent-safe, good for detail screens)
// GET /api/v1/favorites/exists?entityType=&entityId=
router.get('/exists', requireAuth, favoritesController.exists);

// Summary counts for chips/facets (by entityType and tags)
// GET /api/v1/favorites/summary
router.get('/summary', requireAuth, favoritesController.getSummary);

// Add a favorite (creates if not exists due to unique compound index)
// POST /api/v1/favorites
// Body: { entityType, entityId, tags?, note? }
router.post('/', requireAuth, favoritesController.addFavorite);

// Toggle favorite on/off for an entity (idempotent behavior in controller)
// POST /api/v1/favorites/toggle
// Body: { entityType, entityId, tags?, note? }
router.post('/toggle', requireAuth, favoritesController.toggleFavorite);

// Update a favorite’s note/tags/flags
// PATCH /api/v1/favorites/:id
// Body: { note?, tags?, isArchived?, isHidden? }
router.patch('/:id', requireAuth, favoritesController.updateFavorite);

// Add tags to a favorite
// POST /api/v1/favorites/:id/tags
// Body: { tags: [] }
router.post('/:id/tags', requireAuth, favoritesController.addTags);

// Remove tags from a favorite
// DELETE /api/v1/favorites/:id/tags
// Body: { tags: [] }
router.delete('/:id/tags', requireAuth, favoritesController.removeTags);

// Remove a favorite by id
// DELETE /api/v1/favorites/:id
router.delete('/:id', requireAuth, favoritesController.removeFavorite);

// Remove a favorite by entity composite (useful from detail screens without list fetch)
// DELETE /api/v1/favorites/by-entity?entityType=&entityId=
router.delete('/by-entity', requireAuth, favoritesController.removeFavoriteByEntity);

// Bulk add favorites
// POST /api/v1/favorites/bulk
// Body: { items: [{ entityType, entityId, tags?, note? }, ...] }
router.post('/bulk', requireAuth, favoritesController.bulkAddFavorites);

// Bulk remove favorites by entity composite
// DELETE /api/v1/favorites/bulk
// Body: { items: [{ entityType, entityId }, ...] }
router.delete('/bulk', requireAuth, favoritesController.bulkRemoveFavorites);

module.exports = router;
