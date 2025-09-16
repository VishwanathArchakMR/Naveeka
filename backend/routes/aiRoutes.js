// C:\flutterapp\myapp\backend\routes\aiRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (adjust import path if different)
const { requireAuth } = require('../middlewares/auth');

// Controller (ensure controllers/aiController.js implements these handlers)
const aiController = require('../controllers/aiController');

// Health check
// GET /api/v1/ai/health
router.get('/health', aiController.health);

// Models available to the AI layer (useful for feature toggles)
// GET /api/v1/ai/models
router.get('/models', aiController.listModels);

// General chat completion (JSON request/response)
// POST /api/v1/ai/chat
router.post('/chat', requireAuth, aiController.chat);

// Streaming chat over Server-Sent Events (SSE) with proper headers
// GET /api/v1/ai/chat/stream
router.get('/chat/stream', requireAuth, aiController.chatStream);

// Generate multi-day trip ideas or skeleton itineraries
// POST /api/v1/ai/trip-ideas
router.post('/trip-ideas', requireAuth, aiController.tripIdeas);

// Generate a single-day plan with time blocks and ISO 8601 slots
// POST /api/v1/ai/day-plan
router.post('/day-plan', requireAuth, aiController.dayPlan);

// Generate a smart packing list based on destination, dates, and activities
// POST /api/v1/ai/packing-list
router.post('/packing-list', requireAuth, aiController.packingList);

// Translate arbitrary text between languages
// POST /api/v1/ai/translate
router.post('/translate', requireAuth, aiController.translate);

// Rewrite text for tone/clarity/length
// POST /api/v1/ai/rewrite
router.post('/rewrite', requireAuth, aiController.rewrite);

// Summarize content (e.g., bookings, long descriptions, policies)
// POST /api/v1/ai/summarize
router.post('/summarize', requireAuth, aiController.summarize);

// Extract entities/keywords/places from text for quick tagging or search
// POST /api/v1/ai/extract
router.post('/extract', requireAuth, aiController.extractEntities);

module.exports = router;
