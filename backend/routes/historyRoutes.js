// C:\flutterapp\myapp\backend\routes\historyRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (history is user-scoped)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/historyController.js implements these handlers)
const historyController = require('../controllers/historyController');

// Health check
// GET /api/v1/history/health
router.get('/health', historyController.health);

// Summary stats (counts/distance/fare by action/kind within a date range)
// GET /api/v1/history/stats?start=ISO&end=ISO&groupBy=action|kind
router.get('/stats', requireAuth, historyController.getStats);

// Timeline (grouped by day with pagination cursors)
// GET /api/v1/history/timeline?start=ISO&end=ISO&cursor=&limit=&kind=&action=&entityType=&tags=
router.get('/timeline', requireAuth, historyController.getTimeline);

// RFC 7946 FeatureCollection for map overlays (supports bbox/date filters)
// GET /api/v1/history/geojson?start=ISO&end=ISO&minLng=&minLat=&maxLng=&maxLat=&limit=
router.get('/geojson', requireAuth, historyController.getGeoJSON);

// Recently interacted entities for quick rebook/open
// GET /api/v1/history/recent?entityType=&limit=
router.get('/recent', requireAuth, historyController.getRecent);

// Export (CSV) over a date range and optional filters
// GET /api/v1/history/export?format=csv&start=ISO&end=ISO&kind=&action=&entityType=&tags=
router.get('/export', requireAuth, historyController.exportHistory);

// List history with filters/pagination
// GET /api/v1/history?start=ISO&end=ISO&kind=&action=&entityType=&tags=&page=&limit=
router.get('/', requireAuth, historyController.getHistory);

// Create a history event
// POST /api/v1/history
// Body: { kind, entityType, entityId?, action, startedAt, endedAt?, location?, route?, fromRef?, toRef?, distanceKm?, fare?, currency?, tags?, notes?, metadata? }
router.post('/', requireAuth, historyController.createHistory);

// Get a single history event by id
// GET /api/v1/history/:id
router.get('/:id', requireAuth, historyController.getHistoryById);

// Update a history event (notes/tags/times/route/flags)
// PATCH /api/v1/history/:id
// Body: { notes?, tags?, startedAt?, endedAt?, location?, route?, isActive? }
router.patch('/:id', requireAuth, historyController.updateHistory);

// Delete a history event
// DELETE /api/v1/history/:id
router.delete('/:id', requireAuth, historyController.deleteHistory);

// Bulk add history events
// POST /api/v1/history/bulk
// Body: { items: [ { ...history fields... }, ... ] }
router.post('/bulk', requireAuth, historyController.bulkCreate);

// Bulk delete by ids
// DELETE /api/v1/history/bulk
// Body: { ids: [ "...", "..." ] }
router.delete('/bulk', requireAuth, historyController.bulkDelete);

module.exports = router;
