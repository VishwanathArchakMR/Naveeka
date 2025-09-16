// C:\flutterapp\myapp\backend\models\History.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON Point in [lng, lat] with range validation.
 * Stored with a 2dsphere index for $near and spatial queries.
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
 * GeoJSON LineString for routes (e.g., flights, trains, buses, cabs) with [lng, lat] pairs.
 * Indexed as 2dsphere for spatial operations and map overlays.
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
        message: 'route.coordinates must be an array of [lng, lat] pairs within valid ranges'
      }
    }
  },
  { _id: false }
);

/**
 * Generic reference for from/to endpoints (airports, stations, stops, places).
 * Keeps a light denormalized snapshot for quick list rendering and rebook flows.
 */
const placeRefSchema = new Schema(
  {
    entityType: { type: String, trim: true },        // airport|train_station|bus_stop|place|hotel|activity
    entityId: { type: Schema.Types.ObjectId },       // referenced document id
    code: { type: String, trim: true },              // IATA/ICAO/station_code/stop_code if applicable
    name: { type: String, trim: true },
    location: { type: pointSchema }                  // optional point for quick distance math
  },
  { _id: false }
);

const HistorySchema = new Schema(
  {
    // Ownership
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    // High-level classification (optional): transport|lodging|activity|poi|social|system
    kind: { type: String, trim: true, index: true },

    // Entity info: what object this history references (flight/train/bus/cab/hotel/restaurant/activity/place/etc.)
    entityType: { type: String, required: true, trim: true, index: true },
    entityId: { type: Schema.Types.ObjectId, index: true },

    // Action performed: viewed|visited|booked|completed|cancelled|reviewed|favorited|shared|searched
    action: { type: String, required: true, trim: true, index: true },

    // Time range (ISO 8601 friendly Date fields)
    startedAt: { type: Date, required: true, index: true }, // use new Date(isoString)
    endedAt: { type: Date },                                // optional end time

    // Primary location and optional full route
    location: { type: pointSchema, index: '2dsphere' },     // used for $near queries and map pin
    route: { type: lineStringSchema, index: '2dsphere' },   // used for route overlays (LineString)

    // Origin/Destination (light denormalized snapshot for transport or movement-related items)
    fromRef: { type: placeRefSchema },
    toRef: { type: placeRefSchema },

    // Measures and money
    distanceKm: { type: Number, min: 0 },                   // traveled/estimated distance
    fare: { type: Number, min: 0 },                         // monetary spend for the item
    currency: { type: String, trim: true },                 // ISO 4217 code, e.g., INR, USD

    // Labels and user notes
    tags: [{ type: String, trim: true, index: true }],
    notes: { type: String, trim: true },

    // Flags
    isActive: { type: Boolean, default: true, index: true },

    // Provider-specific or app-specific extra data (PNR, booking ids, payloads)
    metadata: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true,                   // createdAt, updatedAt
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

// Text index for free-text filtering on notes (and possibly tags)
HistorySchema.index(
  { notes: 'text', tags: 'text' },
  { name: 'history_text_idx', weights: { notes: 5, tags: 3 } }
);

// Common query patterns
HistorySchema.index({ userId: 1, startedAt: -1 });                          // timeline sorting
HistorySchema.index({ userId: 1, entityType: 1, action: 1, startedAt: -1 }); // list by type/action
HistorySchema.index({ currency: 1 });                                        // expense summaries
HistorySchema.index({ 'fromRef.entityType': 1, 'toRef.entityType': 1 });     // transport filters

// Virtual: duration in minutes (if both timestamps are present)
HistorySchema.virtual('durationMin').get(function () {
  if (!this.startedAt || !this.endedAt) return null;
  const diff = (this.endedAt.getTime() - this.startedAt.getTime()) / 60000;
  return Math.max(0, Math.round(diff));
});

// Helper: emit minimal RFC 7946 FeatureCollection for map overlays
HistorySchema.methods.toGeoJSON = function () {
  const features = [];

  if (this.location?.coordinates) {
    features.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: this.location.coordinates },
      properties: {
        id: this._id,
        entityType: this.entityType,
        action: this.action,
        startedAt: this.startedAt,
        endedAt: this.endedAt,
        geo: `geo:${this.location.coordinates},${this.location.coordinates}`
      }
    });
  }

  if (this.route?.type === 'LineString' && Array.isArray(this.route.coordinates)) {
    features.push({
      type: 'Feature',
      geometry: this.route,
      properties: {
        id: this._id,
        kind: 'route',
        entityType: this.entityType,
        distanceKm: this.distanceKm || null
      }
    });
  }

  return { type: 'FeatureCollection', features };
};

module.exports = mongoose.model('History', HistorySchema);
