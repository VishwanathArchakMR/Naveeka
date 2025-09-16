// C:\flutterapp\myapp\backend\models\Restaurant.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON Point [lng, lat] with bounds validation and 2dsphere support.
 */
const pointSchema = new Schema(
  {
    type: { type: String, enum: ['Point'], required: true },
    coordinates: {
      // [longitude, latitude]
      type: [Number],
      required: true,
      validate: {
        validator: (arr) =>
          Array.isArray(arr) &&
          arr.length === 2 &&
          arr >= -180 &&
          arr <= 180 &&
          arr >= -90 &&
          arr <= 90,
        message: 'coordinates must be [lng, lat] within valid ranges'
      }
    }
  },
  { _id: false }
);

/**
 * Address with denormalized city/country for fast filters.
 */
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

/**
 * Price info and simple level indicator for filters.
 */
const priceSchema = new Schema(
  {
    estimate: { type: Number, min: 0, default: 0 },  // indicative avg price per person
    currency: { type: String, trim: true, default: 'USD' }
  },
  { _id: false }
);

/**
 * Weekly opening hours expressed with ISO 8601 time windows.
 */
const openingWindowSchema = new Schema(
  {
    startISO: { type: String, trim: true }, // ISO 8601 (local time or datetime with offset)
    endISO: { type: String, trim: true }    // ISO 8601 (local time or datetime with offset)
  },
  { _id: false }
);

const hoursSchema = new Schema(
  {
    mon: { type: [openingWindowSchema], default: [] },
    tue: { type: [openingWindowSchema], default: [] },
    wed: { type: [openingWindowSchema], default: [] },
    thu: { type: [openingWindowSchema], default: [] },
    fri: { type: [openingWindowSchema], default: [] },
    sat: { type: [openingWindowSchema], default: [] },
    sun: { type: [openingWindowSchema], default: [] }
  },
  { _id: false }
);

/**
 * Aggregated reviews for list/detail; individual reviews live in Review collection.
 */
const reviewAggregateSchema = new Schema(
  {
    averageRating: { type: Number, min: 0, max: 5, default: 0 },
    totalReviews: { type: Number, min: 0, default: 0 }
  },
  { _id: false }
);

const RestaurantSchema = new Schema(
  {
    // Identity
    name: { type: String, required: true, trim: true, index: true },
    slug: { type: String, trim: true, index: true },
    description: { type: String, trim: true },

    // Classification
    cuisines: [{ type: String, trim: true, index: true }],   // e.g., Indian, Chinese, Italian
    price: priceSchema,                                       // avg price per person + currency
    priceLevel: { type: String, trim: true, index: true },    // $, $$, $$$, $$$$
    dietaryOptions: [{ type: String, trim: true, index: true }], // vegan, vegetarian, halal, etc.
    features: [{ type: String, trim: true, index: true }],        // delivery, takeaway, outdoor_seating, reservations, etc.
    tags: [{ type: String, trim: true, index: true }],

    // Location and addressing
    address: addressSchema,
    city: { type: String, trim: true, index: true },    // denormalized for quick reads
    country: { type: String, trim: true, index: true }, // denormalized for quick reads
    tz: { type: String, trim: true },                   // IANA timezone
    location: {
      type: pointSchema,
      required: true,
      index: '2dsphere'
    },

    // Opening hours and dynamic state
    hours: hoursSchema,
    openNow: { type: Boolean, default: false, index: true }, // refreshed by a service or TTL task

    // Media
    photos: [{ type: String, trim: true }],
    gallery: [{ type: String, trim: true }],

    // Reviews aggregate
    reviews: reviewAggregateSchema,

    // Ops metrics
    bookingsCount: { type: Number, min: 0, default: 0 },
    viewCount: { type: Number, min: 0, default: 0 },
    popularity: { type: Number, min: 0, default: 0 },

    // Contact
    phone: { type: String, trim: true },
    website: { type: String, trim: true },

    // Flags
    isActive: { type: Boolean, default: true, index: true },

    // Misc
    metadata: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true, // createdAt, updatedAt
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

// Text index for search and suggestions across key fields with weights
RestaurantSchema.index(
  {
    name: 'text',
    city: 'text',
    country: 'text',
    cuisines: 'text',
    tags: 'text',
    features: 'text',
    description: 'text'
  },
  {
    name: 'restaurant_text_idx',
    weights: {
      name: 10,
      cuisines: 7,
      city: 6,
      country: 3,
      tags: 3,
      features: 2,
      description: 1
    }
  }
);

// Common filter/sort aids for controllers
RestaurantSchema.index({ 'reviews.averageRating': -1, popularity: -1, viewCount: -1 });
RestaurantSchema.index({ 'price.estimate': 1, 'reviews.averageRating': -1 });
RestaurantSchema.index({ city: 1, 'reviews.averageRating': -1, popularity: -1 });
RestaurantSchema.index({ isActive: 1, createdAt: -1 });

// Slugify name if absent
RestaurantSchema.pre('save', function (next) {
  if (!this.slug && this.name) {
    this.slug = this.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')
      .substring(0, 120);
  }
  next();
});

// Instance: RFC 7946 Feature for map overlays and geo deep link
RestaurantSchema.methods.toGeoJSONFeature = function () {
  if (!this.location?.coordinates) return null;
  const [lng, lat] = this.location.coordinates;
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] },
    properties: {
      id: this._id,
      type: 'restaurant',
      name: this.name,
      city: this.city || this.address?.city || null,
      country: this.country || this.address?.country || null,
      tz: this.tz || null,
      cuisines: this.cuisines || [],
      priceLevel: this.priceLevel || null,
      rating: this.reviews?.averageRating || null,
      openNow: !!this.openNow,
      geo: `geo:${lat},${lng}`
    }
  };
};

module.exports = mongoose.model('Restaurant', RestaurantSchema);
