// C:\flutterapp\myapp\backend\models\Train.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON LineString [ [lng,lat], ... ] for the trip route geometry.
 * Indexed with 2dsphere for spatial queries and map overlays.
 */
const lineStringSchema = new Schema(
  {
    type: { type: String, enum: ['LineString'], required: true },
    coordinates: {
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
 * GTFS-like stop_times structure for ordered stops on a train trip.
 * Times are stored as ISO 8601 strings (local with offset handled upstream).
 */
const stopSchema = new Schema(
  {
    seq: { type: Number, min: 0, required: true, index: true },           // stop sequence order
    stationRefId: { type: Schema.Types.ObjectId, ref: 'TrainStation', required: true, index: true },
    name: { type: String, trim: true },                                    // denormalized label
    arr: { type: String, trim: true },                                     // ISO 8601 arrival time
    dep: { type: String, trim: true },                                     // ISO 8601 departure time
    platform: { type: String, trim: true },
    distance_km: { type: Number, min: 0 }
  },
  { _id: false }
);

/**
 * Fare bands for classes and summary display.
 */
const fareBandSchema = new Schema(
  {
    classCode: { type: String, trim: true }, // e.g., 2S, SL, 3A, 2A, 1A, CC, EC
    currency: { type: String, trim: true, default: 'USD' },
    min: { type: Number, min: 0 },
    max: { type: Number, min: 0 }
  },
  { _id: false }
);

/**
 * Service days and validity window (calendar/calendar_dates semantics).
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
 * Review aggregates; individual reviews stored separately.
 */
const reviewAggregateSchema = new Schema(
  {
    averageRating: { type: Number, min: 0, max: 5, default: 0 },
    totalReviews: { type: Number, min: 0, default: 0 }
  },
  { _id: false }
);

/**
 * Policy hints (refund/reschedule, baggage, etc.).
 */
const policySchema = new Schema(
  {
    refundPolicy: { type: String, trim: true },
    reschedulePolicy: { type: String, trim: true },
    terms: { type: String, trim: true }
  },
  { _id: false }
);

const TrainSchema = new Schema(
  {
    // Identification
    number: { type: String, required: true, trim: true, index: true }, // train number
    name: { type: String, trim: true, index: true },                   // marketed name
    operator: { type: String, required: true, trim: true, index: true }, // operator/railway

    // Classification and features
    classes: [{ type: String, trim: true, index: true }],  // class codes available on the trip
    amenities: [{ type: String, trim: true }],             // pantry, wifi, bedding, etc.
    policies: policySchema,

    // Operating days and validity
    serviceDays: serviceDaysSchema,
    validity: validitySchema,

    // Route and schedule
    stops: { type: [stopSchema], default: [] },            // ordered GTFS-like stops
    fares: { type: [fareBandSchema], default: [] },        // fare bands per class
    routeShapeRef: { type: String, trim: true },           // optional external shape id
    routeShape: {
      // Optional polyline [ [lng,lat], ... ] if not stored as GeoJSON
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
    coordinatesGeoJSON: { type: lineStringSchema, index: '2dsphere' }, // preferred route geometry

    // Ratings and engagement
    rating: { type: Number, min: 0, max: 5, default: 0 },  // optional denorm for quick sort
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

// Text index for search and suggestions across key identifiers and stop names
TrainSchema.index(
  {
    number: 'text',
    name: 'text',
    operator: 'text',
    'stops.name': 'text'
  },
  {
    name: 'train_text_idx',
    weights: { number: 9, name: 7, operator: 5, 'stops.name': 3 }
  }
);

// Common query patterns and sorting aids
TrainSchema.index({ operator: 1, popularity: -1, viewCount: -1 });
TrainSchema.index({ 'stops.stationRefId': 1 }); // used by “serving-trains” endpoint
TrainSchema.index({ isActive: 1, createdAt: -1 });
TrainSchema.index({ 'reviews.averageRating': -1, popularity: -1 });

// Helper: return stops ordered by seq
TrainSchema.methods.getOrderedStops = function () {
  return (this.stops || []).slice().sort((a, b) => (a.seq || 0) - (b.seq || 0));
};

module.exports = mongoose.model('Train', TrainSchema);
