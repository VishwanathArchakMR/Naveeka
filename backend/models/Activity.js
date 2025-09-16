// C:\flutterapp\myapp\backend\models\Activity.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON Point schema (RFC 7946) with [lng, lat] order
 * https://mongoosejs.com/docs/geojson.html
 */
const pointSchema = new Schema(
  {
    type: {
      type: String,
      enum: ['Point'],
      required: true
    },
    coordinates: {
      // [longitude, latitude]
      type: [Number],
      required: true,
      validate: {
        validator: (arr) => Array.isArray(arr) && arr.length === 2,
        message: 'coordinates must be [lng, lat]'
      }
    }
  },
  { _id: false }
);

// Pricing, taxes, fees
const pricingSchema = new Schema(
  {
    currency: { type: String, default: 'USD', trim: true },
    basePrice: { type: Number, min: 0, default: 0 },
    taxes: { type: Number, min: 0, default: 0 },
    fees: { type: Number, min: 0, default: 0 },
    // Optional rules: seasonal/day-based/participant-based adjustments
    rules: [
      {
        name: { type: String, trim: true },
        startsAtISO: { type: String, trim: true }, // ISO 8601 string
        endsAtISO: { type: String, trim: true }, // ISO 8601 string
        weekdays: [{ type: Number, min: 0, max: 6 }],
        minParticipants: { type: Number, min: 1 },
        maxParticipants: { type: Number, min: 1 },
        multiplier: { type: Number, default: 1 } // multiplier for basePrice
      }
    ]
  },
  { _id: false }
);

// Availability: simple calendar dates plus optional slotting
const availabilitySchema = new Schema(
  {
    // Calendar days available (UTC dates or local-time strings parsed downstream)
    dates: [{ type: Date }],
    // Optional explicit time slots for richer scheduling
    slots: [
      {
        startISO: { type: String, trim: true }, // ISO 8601
        endISO: { type: String, trim: true }, // ISO 8601
        capacity: { type: Number, min: 1 },
        remaining: { type: Number, min: 0 }
      }
    ]
  },
  { _id: false }
);

// Capacity and duration
const capacitySchema = new Schema(
  {
    minParticipants: { type: Number, min: 1, default: 1 },
    maxParticipants: { type: Number, min: 1, default: 20 }
  },
  { _id: false }
);

const durationSchema = new Schema(
  {
    hours: { type: Number, min: 0, default: 2 },
    minutes: { type: Number, min: 0, max: 59, default: 0 }
  },
  { _id: false }
);

// Review aggregates stored on activity (individual reviews are in Review collection)
const reviewAggregateSchema = new Schema(
  {
    averageRating: { type: Number, min: 0, max: 5, default: 0 },
    totalReviews: { type: Number, min: 0, default: 0 }
  },
  { _id: false }
);

// Policies and requirements
const policySchema = new Schema(
  {
    freeCancellationUntilHours: { type: Number, min: 0, default: 24 },
    minAge: { type: Number, min: 0, default: 0 },
    safetyGearRequired: { type: Boolean, default: false },
    notes: { type: String, trim: true }
  },
  { _id: false }
);

const addressSchema = new Schema(
  {
    line1: { type: String, trim: true },
    line2: { type: String, trim: true },
    city: { type: String, trim: true, index: true },
    state: { type: String, trim: true },
    country: { type: String, trim: true, index: true },
    postalCode: { type: String, trim: true }
  },
  { _id: false }
);

const ActivitySchema = new Schema(
  {
    // Core identity
    name: { type: String, required: true, trim: true },
    slug: { type: String, trim: true, index: true },
    description: { type: String, trim: true },

    // Classification
    category: { type: String, trim: true, index: true }, // e.g., adventure, cultural, nature, food, entertainment, sports, wellness
    subcategories: [{ type: String, trim: true }],
    difficulty: { type: String, trim: true, enum: ['easy', 'medium', 'hard', 'expert'], default: 'easy', index: true },
    tags: [{ type: String, trim: true, index: true }],

    // Provider information (partner/merchant)
    provider: { type: Schema.Types.ObjectId, ref: 'Provider', index: true },

    // Location and addressing
    address: addressSchema,
    location: {
      type: pointSchema,
      required: true,
      index: '2dsphere' // required for $near and other geospatial queries
    },

    // Language/culture
    languages: [{ type: String, trim: true }], // e.g., 'en', 'hi', 'fr'

    // Duration and capacity
    duration: durationSchema,
    capacity: capacitySchema,

    // Pricing
    pricing: pricingSchema,

    // Availability and policies
    availability: availabilitySchema,
    policies: policySchema,

    // Media
    photos: [{ type: String, trim: true }],
    gallery: [{ type: String, trim: true }],
    videos: [{ type: String, trim: true }],

    // Aggregated reviews (details live in Review collection)
    reviews: reviewAggregateSchema,

    // Operational flags and metrics
    bookingEnabled: { type: Boolean, default: true },
    isActive: { type: Boolean, default: true, index: true },
    bookingCount: { type: Number, min: 0, default: 0 },
    viewCount: { type: Number, min: 0, default: 0 },
    favoriteCount: { type: Number, min: 0, default: 0 },

    // Meta
    tz: { type: String, trim: true }, // timezone for local scheduling
    metadata: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

// Virtual: computed total duration in minutes
ActivitySchema.virtual('duration.totalMinutes').get(function () {
  const h = this.duration?.hours || 0;
  const m = this.duration?.minutes || 0;
  return h * 60 + m;
});

// Text index for search relevance across key fields (single text index with weights)
ActivitySchema.index(
  {
    name: 'text',
    description: 'text',
    category: 'text',
    'address.city': 'text',
    tags: 'text'
  },
  {
    name: 'activity_text_idx',
    weights: {
      name: 8,
      category: 5,
      'address.city': 4,
      tags: 3,
      description: 2
    }
  }
);

// Helpful compound indexes for common sort/filter combos
ActivitySchema.index({ category: 1, 'reviews.averageRating': -1 });
ActivitySchema.index({ isActive: 1, bookingEnabled: 1 });
ActivitySchema.index({ 'address.city': 1, bookingCount: -1 });
ActivitySchema.index({ 'reviews.averageRating': -1, bookingCount: -1, viewCount: -1 });

// Slugify name if missing slug
ActivitySchema.pre('save', function (next) {
  if (!this.slug && this.name) {
    this.slug = this.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')
      .substring(0, 120);
  }
  next();
});

// Static: update aggregate rating from Review collection (optional helper)
ActivitySchema.statics.recalculateRating = async function (activityId, ReviewModel) {
  const agg = await ReviewModel.aggregate([
    { $match: { activityId: new mongoose.Types.ObjectId(activityId), isActive: true } },
    { $group: { _id: '$activityId', avg: { $avg: '$rating' }, total: { $sum: 1 } } }
  ]);
  const a = agg?.[0] || null;
  await this.findByIdAndUpdate(activityId, {
    $set: {
      'reviews.averageRating': a ? Math.round(a.avg * 10) / 10 : 0,
      'reviews.totalReviews': a ? a.total : 0
    }
  });
};

// Instance: minimal GeoJSON Feature for map layers
ActivitySchema.methods.toGeoJSONFeature = function () {
  if (!this.location?.coordinates) return null;
  const [lng, lat] = this.location.coordinates;
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] }, // [lng, lat]
    properties: {
      id: this._id,
      type: 'activity',
      name: this.name,
      category: this.category || null,
      city: this.address?.city || null,
      country: this.address?.country || null,
      tz: this.tz || null,
      rating: this.reviews?.averageRating || null,
      price: this.pricing?.basePrice || null,
      currency: this.pricing?.currency || null,
      geo: `geo:${lat},${lng}`
    }
  };
};

module.exports = mongoose.model('Activity', ActivitySchema);
