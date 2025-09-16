// backend/models/booking/Booking.js
const mongoose = require('mongoose');
const { BOOKING_STATUS } = require('../../utils/constants');

const bookingSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    experienceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Experience', required: true, index: true },

    startDate: { type: Date },
    endDate: { type: Date },
    guests: { type: Number, min: 1, default: 1 },

    price: { type: Number, min: 0, default: 0 },
    currency: { type: String, default: 'INR' },

    status: { type: String, enum: BOOKING_STATUS, default: 'pending', index: true }, // pending/confirmed/cancelled/completed [3]
    paymentStatus: { type: String, enum: ['unpaid', 'paid', 'refunded'], default: 'unpaid', index: true },

    reference: { type: String, trim: true } // external ref / PNR / provider code
  },
  { timestamps: true }
);

// Useful indexes
bookingSchema.index({ userId: 1, createdAt: -1 });         // "My bookings" recent-first [4]
bookingSchema.index({ status: 1, startDate: 1 });          // upcoming by status [10]
bookingSchema.index({ experienceId: 1, createdAt: -1 });   // provider/admin views [4]

module.exports = mongoose.model('Booking', bookingSchema);
