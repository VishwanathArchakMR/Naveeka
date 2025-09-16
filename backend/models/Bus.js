// C:\flutterapp\myapp\backend\models\Bus.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON LineString (RFC 7946) for route geometry with [lng, lat] order.
 * A 2dsphere index enables spatial operations and consistent map overlays. 
 */
const lineStringSchema = new Schema(
  {
    type: { type: String, enum: ['LineString'], required: true },
    coordinates: {
      // [[lng, lat], [lng, lat], ...]
      type: [[Number]],
      required: true,
      validate: {
        validator: (arr) =>
          Array.isArray(arr) &&
          arr.length >= 2 &&
          arr.every(
            (pt) =>
              Array.isArray(pt) &&
              pt.length === 2 &&
              pt >= -180 &&
              pt <= 180 &&
              pt >= -90 &&
              pt <= 90
          ),
        message: 'coordinates must be an array of [lng, lat] pairs within valid ranges'
      }
    }
  },
  { _id: false }
);

/**
 * GTFS-like stop_times structure for ordered stops on a trip.
 * Times are stored as ISO-like strings (with timezone offset handled upstream). 
 */
const stopSchema = new Schema(
  {
    seq: { type: Number, min: 0, required: true, index: true }, // order along the route
    stopRefId: { type: Schema.Types.ObjectId, ref: 'BusStop', required: true, index: true },
    name: { type: String, trim: true },
    arr: { type: String, trim: true }, // ISO 8601 string (local with offset)
    dep: { type: String, trim: true }, // ISO 8601 string (local with offset)
    platform: { type: String, trim: true },
    bay: { type: String, trim: true },
    distance_km: { type: Number, min: 0 }
  },
  { _id: false }
);

/**
 * Fare bands for quick UI rendering and aggregations.
 */
const fareBandSchema = new Schema(
  {
    classCode: { type: String, trim: true }, // e.g., SEATER, SLEEPER, AC
    currency: { type: String, trim: true, default: 'USD' },
    min: { type: Number, min: 0 },
    max: { type: Number, min: 0 }
  },
  { _id: false }
);

/**
 * Service validity and operating days.
 */
const serviceDaysSchema = new Schema(
  {
    mon: { type: Boolean, default: true },
    tue: { type: Boolean, default: true },
    wed: { type: Boolean, default: true },
    thu: { type: Boolean, default: true },
    fri: { type: Boolean, default: true },
    sat: { type: Boolean, default: true },
    sun: { type: Boolean, default: true }
  },
  { _id: false }
);

const validitySchema = new Schema(
  {
    startDate: { type: Date },
    endDate: { type: Date }
  },
  { _id: false }
);

/**
 * Aggregated reviews for listing; individual reviews are separate documents.
 */
const reviewAggregateSchema = new Schema(
  {
    averageRating: { type: Number, min: 0, max: 5, default: 0 },
    totalReviews: { type: Number, min: 0, default: 0 }
  },
  { _id: false }
);

/**
 * Policy hints for UI.
 */
const policySchema = new Schema(
  {
    freeCancellationUntilMinutes: { type: Number, min: 0, default: 60 },
    rescheduleAllowed: { type: Boolean, default: true },
    terms: { type: String, trim: true }
  },
  { _id: false }
);

const BusSchema = new Schema(
  {
    // Identification
    number: { type: String, required: true, trim: true, index: true }, // route/coach number
    name: { type: String, trim: true, index: true },                   // marketed name
    operator: { type: String, required: true, trim: true, index: true },

    // Classification and features
    classes: [{ type: String, trim: true, index: true }],   // e.g., SEATER, SLEEPER, AC
    amenities: [{ type: String, trim: true }],              // wifi, charging, snacks, etc.
    policies: policySchema,

    // Operations
    serviceDays: serviceDaysSchema,
    validity: validitySchema,

    // Route and schedule
    stops: { type: [stopSchema], default: [] },            // ordered stops (GTFS-like)
    fares: { type: [fareBandSchema], default: [] },        // fare bands for classes
    routeShapeRef: { type: String, trim: true },           // optional external shape id
    routeShape: {
      // Fallback polyline as [ [lng,lat], ... ] if not stored as GeoJSON
      type: [[Number]],
      validate: {
        validator: (arr) =>
          !arr ||
          !arr.length ||
          arr.every(
            (pt) =>
              Array.isArray(pt) &&
              pt.length === 2 &&
              pt >= -180 &&
              pt <= 180 &&
              pt >= -90 &&
              pt <= 90
          ),
        message: 'routeShape must be an array of [lng, lat] pairs'
      }
    },
    coordinatesGeoJSON: {
      // Preferred storage for route as GeoJSON LineString
      type: lineStringSchema,
      index: '2dsphere',
      required: false
    },

    // Ratings and engagement
    rating: { type: Number, min: 0, max: 5, default: 0 },   // optional denorm for quick sort
    reviews: reviewAggregateSchema,
    popularity: { type: Number, min: 0, default: 0 },
    viewCount: { type: Number, min: 0, default: 0 },

    // Flags
    isActive: { type: Boolean, default: true, index: true },

    // Misc
    metadata: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

// Text index to support suggestions and search across key fields and stop names.
BusSchema.index(
  {
    number: 'text',
    name: 'text',
    operator: 'text',
    'stops.name': 'text'
  },
  {
    name: 'bus_text_idx',
    weights: { number: 8, name: 6, operator: 5, 'stops.name': 3 }
  }
);

// Common query patterns and sorting aids
BusSchema.index({ operator: 1, popularity: -1 });
BusSchema.index({ 'stops.stopRefId': 1 }); // used by “serving-buses” endpoint
BusSchema.index({ isActive: 1, viewCount: -1 });
BusSchema.index({ 'reviews.averageRating': -1, popularity: -1 });

// Helper: ensure ordered stops by seq when reading
BusSchema.methods.getOrderedStops = function () {
  return (this.stops || []).slice().sort((a, b) => (a.seq || 0) - (b.seq || 0));
};

module.exports = mongoose.model('Bus', BusSchema);
