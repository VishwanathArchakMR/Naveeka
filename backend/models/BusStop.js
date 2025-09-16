// C:\flutterapp\myapp\backend\models\BusStop.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON Point in [lng, lat] order with 2dsphere index for $near and map queries.
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

const BusStopSchema = new Schema(
  {
    // Identity
    name: { type: String, required: true, trim: true },
    stop_code: { type: String, trim: true, index: true }, // GTFS-like public code for the stop

    // Place info
    address: addressSchema,
    city: { type: String, trim: true, index: true },    // denormalized for quick reads
    country: { type: String, trim: true, index: true }, // denormalized for quick reads
    tz: { type: String, trim: true },                   // IANA timezone (optional)

    // Location
    location: {
      type: pointSchema,
      required: true,
      index: '2dsphere'
    },

    // Facilities and metadata
    amenities: [{ type: String, trim: true }], // shelter, seating, lighting, etc.
    platforms: { type: Number, min: 0 },       // simple count if applicable
    tags: [{ type: String, trim: true }],

    // Engagement metrics
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

// Text index to power suggestions and free-text stop search
BusStopSchema.index(
  {
    name: 'text',
    city: 'text',
    country: 'text',
    stop_code: 'text'
  },
  {
    name: 'bus_stop_text_idx',
    weights: { name: 8, city: 5, country: 3, stop_code: 7 }
  }
);

// Common query patterns used by controllers
BusStopSchema.index({ isActive: 1, popularity: -1, viewCount: -1 });
BusStopSchema.index({ city: 1, popularity: -1 });
BusStopSchema.index({ stop_code: 1 }); // non-unique; codes can collide across regions

// Instance: RFC 7946 Feature for map layers
BusStopSchema.methods.toGeoJSONFeature = function () {
  if (!this.location?.coordinates) return null;
  const [lng, lat] = this.location.coordinates;
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] },
    properties: {
      id: this._id,
      type: 'bus_stop',
      name: this.name,
      stop_code: this.stop_code || null,
      city: this.city || this.address?.city || null,
      country: this.country || this.address?.country || null,
      tz: this.tz || null,
      geo: `geo:${lat},${lng}`
    }
  };
};

module.exports = mongoose.model('BusStop', BusStopSchema);
