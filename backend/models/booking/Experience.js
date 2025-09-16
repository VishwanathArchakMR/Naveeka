// backend/models/booking/Experience.js
const mongoose = require('mongoose');
const { EXPERIENCE_TYPES } = require('../../utils/constants');

const experienceSchema = new mongoose.Schema(
  {
    type: { type: String, enum: EXPERIENCE_TYPES, required: true, index: true }, // stay/activity/darshan/transport [3]
    title: { type: String, required: true, trim: true, maxlength: 150 },
    subtitle: { type: String, trim: true, maxlength: 200 },
    description: { type: String, trim: true, maxlength: 2000 },

    placeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Place', index: true }, // optional link to a specific place
    regionRefs: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Region', index: true }], // broader region association

    media: [{ type: String, trim: true }], // image/video URLs
    basePrice: { type: Number, min: 0, default: 0 }, // indicative price
    currency: { type: String, default: 'INR' },
    providerUrl: { type: String, trim: true }, // deep-link to partner site for MVP checkout

    isActive: { type: Boolean, default: true },
    tags: [{ type: String, trim: true }]
  },
  { timestamps: true }
);

// Indexes for performance
experienceSchema.index({ createdAt: -1 }); // latest first [4]
experienceSchema.index({ type: 1, createdAt: -1 }); // per-type listings [4]

module.exports = mongoose.model('Experience', experienceSchema);
