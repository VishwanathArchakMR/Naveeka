// backend/routes/booking/experienceRoutes.js
const express = require('express');
const { optionalAuth } = require('../../middleware/auth');
const experienceController = require('../../controllers/booking/experienceController');

const router = express.Router();

// GET /api/journey/experiences?type=&regionId=&placeId=&limit=
// Public listing used by the Journey tab to show available experiences. [1][2]
router.get('/', optionalAuth, experienceController.list);

module.exports = router;
