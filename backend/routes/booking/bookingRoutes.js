// backend/routes/booking/bookingRoutes.js
const express = require('express');
const { protect } = require('../../middleware/auth');
const bookingController = require('../../controllers/booking/bookingController');

const router = express.Router();

// GET /api/journey/bookings/mine
// Returns the authenticated user's bookings (current + history)
router.get('/mine', protect, bookingController.myBookings);

module.exports = router;
