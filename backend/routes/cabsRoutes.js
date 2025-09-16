// C:\flutterapp\myapp\backend\routes\cabsRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust import path if different)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/cabsController.js implements these handlers)
const cabsController = require('../controllers/cabsController');

// List available ride types/products near a coordinate
// GET /api/v1/cabs/ride-types?lat=&lng=
router.get('/ride-types', cabsController.getRideTypes);

// Get price/time estimates for a pickup/drop (may call multiple providers)
// POST /api/v1/cabs/estimates
router.post('/estimates', cabsController.getEstimates);

// Request a ride (creates a booking in 'created' or 'pending_payment' state)
// Body: { provider, classCode, pickup:{address,location,whenISO?}, drop:{address,location}, waypoints?, payment? }
// POST /api/v1/cabs/requests
router.post('/requests', requireAuth, cabsController.createRide);

// Get ride details by id (includes driver/vehicle/payment state if available)
// GET /api/v1/cabs/requests/:id
router.get('/requests/:id', requireAuth, cabsController.getRideById);

// Live tracking for a ride (latest lat/lng/heading/speed and timestamps)
// GET /api/v1/cabs/requests/:id/live
router.get('/requests/:id/live', requireAuth, cabsController.getLiveStatus);

// Route geometry as RFC 7946 FeatureCollection (LineString + current position)
// GET /api/v1/cabs/requests/:id/route
router.get('/requests/:id/route', requireAuth, cabsController.getRideRoute);

// Cancel a ride (depending on provider policy)
// POST /api/v1/cabs/requests/:id/cancel
router.post('/requests/:id/cancel', requireAuth, cabsController.cancelRide);

// Confirm/capture payment for a ride if applicable
// POST /api/v1/cabs/requests/:id/pay
router.post('/requests/:id/pay', requireAuth, cabsController.payForRide);

// Provider webhooks for async status updates (no auth; verify signature in controller)
// POST /api/v1/cabs/webhooks/:provider
router.post('/webhooks/:provider', cabsController.webhook);

module.exports = router;
