// C:\flutterapp\myapp\backend\models\Trail.js

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
 * GeoJSON LineString/MultiLineString for the trail path ([lng,lat] order per RFC 7946).
 */
const lineStringSchema = new Schema(
  {
    type: { type: String, enum: ['LineString'], required: true },
    coordinates: {
      type: [[Number]], // [[lng,lat], ...]
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
        message: 'LineString coordinates must be an array of [lng, lat] pairs within valid ranges'
      }
    }
  },
  { _id: false }
);

const multiLineStringSchema = new Schema(
  {
    type: { type: String, enum: ['MultiLineString'], required: true },
    coordinates: {
      type: [[[Number]]], // [ [[lng,lat],...], [[lng,lat],...] ]
      required: true,
      validate: {
        validator: (arr) =>
          Array.isArray(arr) &&
          arr.length >= 1 &&
          arr.every(
            (seg) =>
              Array.isArray(seg) &&
              seg.length >= 2 &&
              seg.every(
                (pt) =>
                  Array.isArray(pt) &&
                  pt.length === 2 &&
                  pt >= -180 &&
                  pt <= 180 &&
                  pt >= -90 &&
                  pt <= 90
              )
          ),
        message: 'MultiLineString coordinates must be arrays of [lng, lat] pairs within valid ranges'
      }
    }
  },
  { _id: false }
);

/**
 * Waypoint with optional type and label.
 */
const waypointSchema = new Schema(
  {
    name: { type: String, trim: true },
    type: { type: String, trim: true }, // viewpoint|water|camp|junction|poi
    coordinates: {
      type: [Number], // [lng, lat]
      required: true,
      validate: {
        validator: (arr) =>
          Array.isArray(arr) &&
          arr.length === 2 &&
          arr >= -180 &&
          arr <= 180 &&
          arr >= -90 &&
          arr <= 90,
        message: 'waypoint.coordinates must be [lng, lat] within valid ranges'
      }
    },
    elevation_m: { type: Number, min: -430, max: 9000 }
  },
  { _id: false }
);

/**
 * Aggregated reviews; individual user reviews live in Review collection.
 */
const reviewAggregateSchema = new Schema(
  {
    averageRating: { type: Number, min: 0, max: 5, default: 0 },
    totalReviews: { type: Number, min: 0, default: 0 }
  },
  { _id: false }
);

/**
 * Seasonal/conditions info using ISO 8601 windows.
 */
const seasonWindowSchema = new Schema(
  {
    startISO: { type: String, trim: true }, // ISO 8601
    endISO: { type: String, trim: true },   // ISO 8601
    note: { type: String, trim: true }
  },
  { _id: false }
);

const TrailSchema = new Schema(
  {
    // Identity and description
    name: { type: String, required: true, trim: true, index: true },
    slug: { type: String, trim: true, index: true },
    description: { type: String, trim: true },

    // Location and region
    address: {
      line1: { type: String, trim: true },
      line2: { type: String, trim: true },
      city: { type: String, trim: true, index: true },
      state: { type: String, trim: true },
      country: { type: String, trim: true, index: true },
      postalCode: { type: String, trim: true }
    },
    city: { type: String, trim: true, index: true },      // denormalized for quick filters
    country: { type: String, trim: true, index: true },   // denormalized for quick filters
    region: { type: String, trim: true, index: true },    // e.g., Western Ghats
    tz: { type: String, trim: true },                     // IANA timezone
    location: {
      type: pointSchema,                                  // trailhead or centroid
      required: true,
      index: '2dsphere'
    },

    // Classification
    types: [{ type: String, trim: true, index: true }],   // hike|run|mtb|cycle|walk|trek
    tags: [{ type: String, trim: true, index: true }],
    loop: { type: Boolean, default: false, index: true },

    // Metrics
    length_km: { type: Number, min: 0, index: true },
    elev_gain_m: { type: Number, min: 0, index: true },
    elev_loss_m: { type: Number, min: 0 },
    max_alt_m: { type: Number, min: -430, max: 9000 },
    min_alt_m: { type: Number, min: -430, max: 9000 },

    // Difficulty
    difficulty: { type: String, trim: true, enum: ['easy', 'moderate', 'hard', 'expert'], index: true },
    difficulty_index: { type: Number, min: 0, index: true }, // precomputed numeric sortable score

    // Path geometry (preferred: GeoJSON)
    path_geojson: { type: Schema.Types.Mixed, index: '2dsphere' }, // LineString or MultiLineString
    // Optional normalized fields if you prefer strict typing:
    coordinatesLine: { type: lineStringSchema, index: '2dsphere' },
    coordinatesMultiLine: { type: multiLineStringSchema, index: '2dsphere' },

    // Waypoints
    waypoints: { type: [waypointSchema], default: [] },
    waypoints_count: { type: Number, min: 0, default: 0 },

    // Media
    photos: [{ type: String, trim: true }],
    gallery: [{ type: String, trim: true }],

    // Reviews aggregate
    reviews: reviewAggregateSchema,

    // Engagement/usage
    completionCount: { type: Number, min: 0, default: 0 },
    viewCount: { type: Number, min: 0, default: 0 },
    popularity: { type: Number, min: 0, default: 0 },

    // Conditions and seasons
    openNow: { type: Boolean, default: true, index: true },
    seasons: { type: [seasonWindowSchema], default: [] },

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

/**
 * Indexes
 */
// Text index for discovery and suggestions
TrailSchema.index(
  {
    name: 'text',
    description: 'text',
    city: 'text',
    country: 'text',
    region: 'text',
    tags: 'text'
  },
  {
    name: 'trail_text_idx',
    weights: { name: 10, city: 6, region: 5, country: 4, tags: 3, description: 2 }
  }
);

// Common filters/sorts used in controllers
TrailSchema.index({ length_km: 1, elev_gain_m: 1 });
TrailSchema.index({ difficulty_index: 1, 'reviews.averageRating': -1 });
TrailSchema.index({ isActive: 1, popularity: -1, viewCount: -1 });
TrailSchema.index({ region: 1, popularity: -1 });
TrailSchema.index({ openNow: 1, updatedAt: -1 });

// Maintain counts and slug
TrailSchema.pre('save', function (next) {
  this.waypoints_count = Array.isArray(this.waypoints) ? this.waypoints.length : 0;
  if (!this.slug && this.name) {
    this.slug = this.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')
      .substring(0, 160);
  }
  next();
});

/**
 * Helpers
 */
// Minimal RFC 7946 Feature for map pins
TrailSchema.methods.toGeoJSONFeature = function () {
  if (!this.location?.coordinates) return null;
  const [lng, lat] = this.location.coordinates;
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] },
    properties: {
      id: this._id,
      type: 'trail',
      name: this.name,
      city: this.city || this.address?.city || null,
      country: this.country || this.address?.country || null,
      region: this.region || null,
      tz: this.tz || null,
      length_km: this.length_km || null,
      elev_gain_m: this.elev_gain_m || null,
      difficulty: this.difficulty || null,
      rating: this.reviews?.averageRating || null,
      geo: `geo:${lat},${lng}`
    }
  };
};

module.exports = mongoose.model('Trail', TrailSchema);
