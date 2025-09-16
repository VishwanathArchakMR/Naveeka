// C:\flutterapp\myapp\backend\models\Airport.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON Point (RFC 7946) in [lng, lat] order with 2dsphere indexing.
 * See Mongoose GeoJSON docs and MongoDB 2dsphere guidance. 
 */
const pointSchema = new Schema(
  {
    type: { type: String, enum: ['Point'], required: true },
    coordinates: {
      type: [Number], // [longitude, latitude]
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
 * Address and location details to support search facets and display.
 */
const addressSchema = new Schema(
  {
    line1: { type: String, trim: true },
    line2: { type: String, trim: true },
    city: { type: String, trim: true, index: true },
    state: { type: String, trim: true },
    country: { type: String, trim: true, index: true },
    countryCode: { type: String, trim: true }, // ISO 3166-1 alpha-2 if available
    postalCode: { type: String, trim: true }
  },
  { _id: false }
);

/**
 * Terminal and runway metadata for details screens.
 */
const terminalSchema = new Schema(
  {
    name: { type: String, trim: true },
    gates: { type: Number, min: 0 },
    amenities: [{ type: String, trim: true }]
  },
  { _id: false }
);

const runwaySchema = new Schema(
  {
    ident: { type: String, trim: true }, // e.g., 09/27
    length_m: { type: Number, min: 0 },
    surface: { type: String, trim: true }
  },
  { _id: false }
);

const reviewAggregateSchema = new Schema(
  {
    averageRating: { type: Number, min: 0, max: 5, default: 0 },
    totalReviews: { type: Number, min: 0, default: 0 }
  },
  { _id: false }
);

const AirportSchema = new Schema(
  {
    // Identity
    name: { type: String, required: true, trim: true },
    slug: { type: String, trim: true, index: true },

    // Codes (IATA 3-letter, ICAO 4-letter)
    iata: {
      type: String,
      trim: true,
      uppercase: true,
      match: [/^[A-Z]{3}$/, 'IATA must be 3 letters'] // IATA standard is 3 letters
    },
    icao: {
      type: String,
      trim: true,
      uppercase: true,
      match: [/^[A-Z]{4}$/, 'ICAO must be 4 letters'] // ICAO standard is 4 letters
    },

    // Place
    address: addressSchema,
    city: { type: String, trim: true, index: true },    // denormalized for quick reads
    country: { type: String, trim: true, index: true }, // denormalized for quick reads
    tz: { type: String, trim: true },                   // IANA timezone

    // Location (GeoJSON)
    location: {
      type: pointSchema,
      required: true,
      index: '2dsphere'
    },

    // Physical details
    terminals: [terminalSchema],
    runways: [runwaySchema],
    elevation_m: { type: Number, min: -430, max: 9000 }, // Dead Sea to Everest range

    // Ops and services
    amenities: [{ type: String, trim: true }],
    services: [{ type: String, trim: true }], // lounges, metro, rail, etc.

    // Aggregates and engagement
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

// Slug fallback
AirportSchema.pre('save', function (next) {
  if (!this.slug && this.name) {
    this.slug = this.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')
      .substring(0, 120);
  }
  next();
});

// Text index for name/city/country/codes to power suggestions and search
AirportSchema.index(
  {
    name: 'text',
    city: 'text',
    country: 'text',
    iata: 'text',
    icao: 'text'
  },
  {
    name: 'airport_text_idx',
    weights: { name: 8, city: 5, country: 3, iata: 9, icao: 7 }
  }
);

// Partial unique indexes for codes when present
AirportSchema.index(
  { iata: 1 },
  {
    unique: true,
    partialFilterExpression: { iata: { $type: 'string', $exists: true, $ne: '' } }
  }
);
AirportSchema.index(
  { icao: 1 },
  {
    unique: true,
    partialFilterExpression: { icao: { $type: 'string', $exists: true, $ne: '' } }
  }
);

// Helpful compound indexes used in controllers
AirportSchema.index({ country: 1, city: 1, popularity: -1 });
AirportSchema.index({ isActive: 1, popularity: -1, viewCount: -1 });

// Instance: GeoJSON feature for atlas/airport layers
AirportSchema.methods.toGeoJSONFeature = function () {
  if (!this.location?.coordinates) return null;
  const [lng, lat] = this.location.coordinates;
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] },
    properties: {
      id: this._id,
      type: 'airport',
      name: this.name,
      iata: this.iata || null,
      icao: this.icao || null,
      city: this.city || this.address?.city || null,
      country: this.country || this.address?.country || null,
      tz: this.tz || null,
      rating: this.reviews?.averageRating || null,
      geo: `geo:${lat},${lng}`
    }
  };
};

module.exports = mongoose.model('Airport', AirportSchema);
