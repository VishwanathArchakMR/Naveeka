// backend/controllers/booking/bookingController.js
const Booking = require('../../models/booking/Booking');

/**
 * GET /api/journey/bookings/mine
 * Returns the authenticated user's bookings, newest first.
 */
exports.myBookings = async (req, res) => {
  try {
    const items = await Booking.find({ userId: req.user._id })
      .sort({ createdAt: -1 });

    res.json({ success: true, data: items });
  } catch (err) {
    console.error('My bookings error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
