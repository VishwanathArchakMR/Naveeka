// backend/routes/social/feedRoutes.js
const express = require('express');
const { optionalAuth } = require('../../middleware/auth');
const feedController = require('../../controllers/social/feedController');

const router = express.Router();

// GET /api/trail/feed/home?limit=
// Personalized if authenticated (follow graph), otherwise global recent feed.
router.get('/home', optionalAuth, feedController.homeFeed);

module.exports = router;
