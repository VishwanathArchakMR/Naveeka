// C:\flutterapp\myapp\backend\models\Hotel.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON Point [lng, lat] with 2dsphere index for $near queries and map overlays.
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
 * Address structure with denormalized city/country for fast filters.
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
 * Pricing model with base price, currency, and optional rules.
 */
const pricingSchema = new Schema(
  {
    currency: { type: String, trim: true, default: 'USD' },
    basePrice: { type: Number, min: 0, default: 0 },
    taxes: { type: Number, min: 0, default: 0 },
    fees: { type: Number, min: 0, default: 0 },
    rules: [
      {
        name: { type: String, trim: true },
        startsAtISO: { type: String, trim: true }, // ISO 8601 string
        endsAtISO: { type: String, trim: true },   // ISO 8601 string
        weekdays: [{ type: Number, min: 0, max: 6 }],
        minNights: { type: Number, min: 1 },
        maxNights: { type: Number, min: 1 },
        multiplier: { type: Number, default: 1 }
      }
    ]
  },
  { _id: false }
);

/**
 * Review aggregates; individual reviews live in Review collection.
 */
const reviewAggregateSchema = new Schema(
  {
    averageRating: { type: Number, min: 0, max: 5, default: 0 },
    totalReviews: { type: Number, min: 0, default: 0 }
  },
  { _id: false }
);

/**
 * Policies and services useful for filters and detail screens.
 */
const policySchema = new Schema(
  {
    freeCancellation: { type: Boolean, default: false, index: true },
    checkInTimeISO: { type: String, trim: true },  // ISO 8601 time or datetime
    checkOutTimeISO: { type: String, trim: true }, // ISO 8601 time or datetime
    smokingPolicy: { type: String, trim: true },
    petPolicy: { type: String, trim: true },
    notes: { type: String, trim: true }
  },
  { _id: false }
);

/**
 * Room types and simple rate plan hooks (details come from availability service).
 */
const roomTypeSchema = new Schema(
  {
    code: { type: String, trim: true },
    name: { type: String, trim: true },
    beds: { type: Number, min: 0 },
    capacity: { type: Number, min: 1 },
    amenities: [{ type: String, trim: true }],
    photos: [{ type: String, trim: true }]
  },
  { _id: false }
);

const ratePlanSchema = new Schema(
  {
    rateId: { type: String, trim: true },
    name: { type: String, trim: true },
    refundable: { type: Boolean, default: true },
    breakfastIncluded: { type: Boolean, default: false },
    price: { type: Number, min: 0 },
    currency: { type: String, trim: true }
  },
  { _id: false }
);

const HotelSchema = new Schema(
  {
    // Core identity
    name: { type: String, required: true, trim: true, index: true },
    slug: { type: String, trim: true, index: true },
    brand: { type: String, trim: true, index: true },
    propertyType: { type: String, trim: true, index: true }, // hotel|aparthotel|hostel|resort|bnb
    stars: { type: Number, min: 0, max: 5, index: true },
    description: { type: String, trim: true },

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

    // Amenities and tags
    amenities: [{ type: String, trim: true }],
    tags: [{ type: String, trim: true, index: true }],

    // Media
    photos: [{ type: String, trim: true }],
    gallery: [{ type: String, trim: true }],

    // Pricing and plans (detailed availability via service)
    pricing: pricingSchema,
    roomTypes: [roomTypeSchema],
    ratePlans: [ratePlanSchema],

    // Aggregated reviews
    reviews: reviewAggregateSchema,

    // Operational metrics
    bookingsCount: { type: Number, min: 0, default: 0 },
    viewCount: { type: Number, min: 0, default: 0 },
    popularity: { type: Number, min: 0, default: 0 },

    // Policies
    policies: policySchema,

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

// Text index for search and suggestions across key fields
HotelSchema.index(
  {
    name: 'text',
    brand: 'text',
    city: 'text',
    country: 'text',
    tags: 'text',
    propertyType: 'text'
  },
  {
    name: 'hotel_text_idx',
    weights: { name: 8, brand: 6, city: 5, country: 3, tags: 3, propertyType: 2 }
  }
);

// Helpful compound indexes for controller filters and sorts
HotelSchema.index({ city: 1, 'reviews.averageRating': -1, bookingsCount: -1 });
HotelSchema.index({ country: 1, popularity: -1, viewCount: -1 });
HotelSchema.index({ 'pricing.basePrice': 1, 'reviews.averageRating': -1 });
HotelSchema.index({ isActive: 1, popularity: -1, createdAt: -1 });

// Slugify name if missing slug
HotelSchema.pre('save', function (next) {
  if (!this.slug && this.name) {
    this.slug = this.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')
      .substring(0, 120);
  }
  next();
});

// Instance: RFC 7946 Feature for map layers and geo deep-link support
HotelSchema.methods.toGeoJSONFeature = function () {
  if (!this.location?.coordinates) return null;
  const [lng, lat] = this.location.coordinates;
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] },
    properties: {
      id: this._id,
      type: 'hotel',
      name: this.name,
      brand: this.brand || null,
      stars: this.stars || null,
      city: this.city || this.address?.city || null,
      country: this.country || this.address?.country || null,
      tz: this.tz || null,
      rating: this.reviews?.averageRating || null,
      price: this.pricing?.basePrice || null,
      currency: this.pricing?.currency || null,
      geo: `geo:${lat},${lng}`
    }
  };
};

module.exports = mongoose.model('Hotel', HotelSchema);
