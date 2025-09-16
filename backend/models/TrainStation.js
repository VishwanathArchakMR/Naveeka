// C:\flutterapp\myapp\backend\models\TrainStation.js

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

const TrainStationSchema = new Schema(
  {
    // Identity (GTFS-like: stop_name, stop_code)
    name: { type: String, required: true, trim: true, index: true }, // stop_name
    station_code: { type: String, trim: true, index: true },         // stop_code (public code)

    // Place info
    address: addressSchema,
    city: { type: String, trim: true, index: true },    // denormalized for quick filters
    country: { type: String, trim: true, index: true }, // denormalized for quick filters
    tz: { type: String, trim: true },                   // IANA timezone

    // Location (GeoJSON Point [lng,lat])
    location: {
      type: pointSchema,
      required: true,
      index: '2dsphere'
    },

    // Facilities and metadata
    amenities: [{ type: String, trim: true }], // restrooms, lounge, food, wifi, etc.
    platforms: { type: Number, min: 0 },       // number of platforms
    tags: [{ type: String, trim: true, index: true }],

    // Engagement metrics
    popularity: { type: Number, min: 0, default: 0 },
    viewCount: { type: Number, min: 0, default: 0 },

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

// Text index to power suggestions and search across key fields
TrainStationSchema.index(
  {
    name: 'text',
    city: 'text',
    country: 'text',
    station_code: 'text',
    tags: 'text'
  },
  {
    name: 'train_station_text_idx',
    weights: { name: 10, city: 6, station_code: 7, country: 3, tags: 2 }
  }
);

// Common filter/sort aids for controllers
TrainStationSchema.index({ isActive: 1, popularity: -1, viewCount: -1 });
TrainStationSchema.index({ city: 1, popularity: -1 });
TrainStationSchema.index({ station_code: 1 }); // non-unique; may collide across regions

// Instance: RFC 7946 Feature for map layers and geo deep link
TrainStationSchema.methods.toGeoJSONFeature = function () {
  if (!this.location?.coordinates) return null;
  const [lng, lat] = this.location.coordinates;
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] }, // [lng,lat]
    properties: {
      id: this._id,
      type: 'train_station',
      name: this.name,
      station_code: this.station_code || null,
      city: this.city || this.address?.city || null,
      country: this.country || this.address?.country || null,
      tz: this.tz || null,
      geo: `geo:${lat},${lng}`
    }
  };
};

module.exports = mongoose.model('TrainStation', TrainStationSchema);
