// C:\flutterapp\myapp\backend\models\Flight.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON LineString for segment/itinerary paths with [lng, lat] order.
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
        message: 'coordinates must be an array of [lng, lat] pairs within valid ranges'
      }
    }
  },
  { _id: false }
);

// Baggage allowance per passenger type
const baggageSchema = new Schema(
  {
    type: { type: String, trim: true }, // CABIN|CHECKED
    quantity: { type: Number, min: 0 },
    weightKg: { type: Number, min: 0 },
    pieceCount: { type: Number, min: 0 },
    note: { type: String, trim: true }
  },
  { _id: false }
);

// Price breakdown and currency
const priceSchema = new Schema(
  {
    currency: { type: String, trim: true, default: 'USD' },
    base: { type: Number, min: 0, default: 0 },
    taxes: { type: Number, min: 0, default: 0 },
    fees: { type: Number, min: 0, default: 0 },
    total: { type: Number, min: 0, default: 0 },
    fareFamily: { type: String, trim: true },
    rules: { type: Schema.Types.Mixed }, // refund/reschedule rules
    expiresAtISO: { type: String, trim: true } // quote expiry (ISO 8601)
  },
  { _id: false }
);

// Ancillary products
const ancillarySchema = new Schema(
  {
    code: { type: String, trim: true }, // e.g., BAG, SEAT, MEAL
    name: { type: String, trim: true },
    price: { type: Number, min: 0 },
    currency: { type: String, trim: true },
    meta: { type: Schema.Types.Mixed }
  },
  { _id: false }
);

// One flight segment (operated leg)
const segmentSchema = new Schema(
  {
    id: { type: String, trim: true }, // provider segment id
    carrier: { type: String, trim: true, index: true }, // e.g., AI
    flightNumber: { type: String, trim: true, index: true }, // e.g., AI123
    operatingCarrier: { type: String, trim: true },
    aircraft: { type: String, trim: true }, // e.g., 320, 77W

    origin: {
      iata: { type: String, uppercase: true, trim: true, match: /^[A-Z]{3}$/ }, // IATA (3)
      icao: { type: String, uppercase: true, trim: true, match: /^[A-Z]{4}$/ }, // ICAO (4)
      terminal: { type: String, trim: true }
    },
    destination: {
      iata: { type: String, uppercase: true, trim: true, match: /^[A-Z]{3}$/ },
      icao: { type: String, uppercase: true, trim: true, match: /^[A-Z]{4}$/ },
      terminal: { type: String, trim: true }
    },

    // Times as ISO 8601 strings (with timezone offsets from provider)
    departureISO: { type: String, trim: true, index: true },
    arrivalISO: { type: String, trim: true, index: true },
    durationMin: { type: Number, min: 0 },

    // Seating and cabin info
    cabinClass: { type: String, trim: true }, // ECONOMY|PREMIUM_ECONOMY|BUSINESS|FIRST
    bookingClass: { type: String, trim: true }, // e.g., Y, J, etc.

    // Optional route geometry for the segment
    path: { type: lineStringSchema },

    // Baggage
    baggage: [baggageSchema],

    // Stop/connection indicator for multi-stop segments
    technicalStop: { type: Boolean, default: false }
  },
  { _id: false }
);

// Traveler fare per passenger type
const travelerFareSchema = new Schema(
  {
    type: { type: String, trim: true }, // ADT|CNN|INF
    count: { type: Number, min: 0, default: 1 },
    price: priceSchema,
    baggage: [baggageSchema]
  },
  { _id: false }
);

// Main Flight (priced itinerary/offer cache)
const FlightSchema = new Schema(
  {
    // Provider/offer references
    provider: { type: String, trim: true, index: true },        // e.g., AMADEUS, SABRE, DIRECT
    offerId: { type: String, trim: true, index: true },         // provider offer id if cached
    searchHash: { type: String, trim: true, index: true },      // hash of search params for de-dupe

    // Itinerary summary
    tripType: { type: String, trim: true },                     // ONE_WAY|ROUND_TRIP|MULTI_CITY
    origin: {
      iata: { type: String, uppercase: true, trim: true, match: /^[A-Z]{3}$/ },
      icao: { type: String, uppercase: true, trim: true, match: /^[A-Z]{4}$/ }
    },
    destination: {
      iata: { type: String, uppercase: true, trim: true, match: /^[A-Z]{3}$/ },
      icao: { type: String, uppercase: true, trim: true, match: /^[A-Z]{4}$/ }
    },

    // Segments in order (one or more)
    segments: { type: [segmentSchema], default: [] },

    // Derived/aggregated fields for quick sorting
    totalDurationMin: { type: Number, min: 0, index: true },
    totalStops: { type: Number, min: 0, index: true },          // sum of connections across journey
    departureISO: { type: String, trim: true, index: true },    // first segment dep ISO
    arrivalISO: { type: String, trim: true, index: true },      // last segment arr ISO

    // Pricing at itinerary level
    price: priceSchema,
    travelerFares: [travelerFareSchema],

    // Ancillary bundles
    ancillaries: [ancillarySchema],

    // Rules/penalties summarized
    fareRules: { type: Schema.Types.Mixed },

    // Optional overall path for map overlay (LineString)
    itineraryPath: { type: lineStringSchema, index: '2dsphere' },

    // Ratings/engagement (optional if needed for UI)
    popularity: { type: Number, min: 0, default: 0 },
    viewCount: { type: Number, min: 0, default: 0 },

    // Flags
    isActive: { type: Boolean, default: true, index: true },

    // Misc metadata (provider-specific)
    metadata: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true, // createdAt, updatedAt
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

// Text index for search/suggestions across key identifiers and airports
FlightSchema.index(
  {
    'segments.flightNumber': 'text',
    'segments.carrier': 'text',
    'origin.iata': 'text',
    'destination.iata': 'text'
  },
  {
    name: 'flight_text_idx',
    weights: { 'segments.flightNumber': 9, 'segments.carrier': 6, 'origin.iata': 7, 'destination.iata': 7 }
  }
);

// Sort/filter aids
FlightSchema.index({ isActive: 1, 'price.total': 1 });
FlightSchema.index({ totalStops: 1, totalDurationMin: 1 });
FlightSchema.index({ departureISO: 1 });
FlightSchema.index({ arrivalISO: 1 });
FlightSchema.index({ provider: 1, offerId: 1 });

// Helper: compute aggregates before save when segments present
FlightSchema.pre('save', function (next) {
  if (Array.isArray(this.segments) && this.segments.length) {
    const segs = this.segments;
    this.departureISO = this.departureISO || segs?.departureISO || null;
    this.arrivalISO = this.arrivalISO || segs[segs.length - 1]?.arrivalISO || null;
    this.totalStops =
      typeof this.totalStops === 'number'
        ? this.totalStops
        : Math.max(0, segs.length - 1);
    if (typeof this.totalDurationMin !== 'number') {
      const sum = segs.reduce((acc, s) => acc + (s.durationMin || 0), 0);
      this.totalDurationMin = sum;
    }
  }
  next();
});

// Instance: minimal GeoJSON FeatureCollection for route map
FlightSchema.methods.toRouteGeoJSON = function () {
  const features = [];

  // Itinerary level line if present
  if (this.itineraryPath?.type === 'LineString' && Array.isArray(this.itineraryPath.coordinates)) {
    features.push({
      type: 'Feature',
      geometry: this.itineraryPath,
      properties: { kind: 'flight_path', offerId: this.offerId || String(this._id) }
    });
  }

  // Segment lines if present
  for (const seg of this.segments || []) {
    if (seg.path?.type === 'LineString' && Array.isArray(seg.path.coordinates)) {
      features.push({
        type: 'Feature',
        geometry: seg.path,
        properties: { kind: 'segment_path', flightNumber: seg.flightNumber, carrier: seg.carrier, segmentId: seg.id || null }
      });
    }
  }

  return { type: 'FeatureCollection', features };
};

module.exports = mongoose.model('Flight', FlightSchema);
