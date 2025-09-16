// C:\flutterapp\myapp\backend\models\Cab.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON Point [lng, lat] with range validation.
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
 * GeoJSON LineString for route geometry [ [lng,lat], ... ].
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

const addressSchema = new Schema(
  {
    label: { type: String, trim: true },
    line1: { type: String, trim: true },
    line2: { type: String, trim: true },
    city: { type: String, trim: true },
    state: { type: String, trim: true },
    country: { type: String, trim: true },
    postalCode: { type: String, trim: true }
  },
  { _id: false }
);

/**
 * Fare/pricing breakdown and currency.
 */
const fareSchema = new Schema(
  {
    currency: { type: String, trim: true, default: 'USD' },
    base: { type: Number, min: 0, default: 0 },
    distanceKm: { type: Number, min: 0, default: 0 },
    durationMin: { type: Number, min: 0, default: 0 },
    surge: { type: Number, min: 0, default: 0 },
    taxes: { type: Number, min: 0, default: 0 },
    fees: { type: Number, min: 0, default: 0 },
    total: { type: Number, min: 0, default: 0 },
    breakdown: { type: Schema.Types.Mixed } // provider-specific items
  },
  { _id: false }
);

/**
 * Payment metadata for checkout and reconciliation.
 */
const paymentSchema = new Schema(
  {
    method: { type: String, trim: true }, // UPI, CARD, WALLET, CASH, etc.
    status: { type: String, trim: true, enum: ['pending', 'authorized', 'captured', 'failed', 'cancelled'], default: 'pending' },
    providerRef: { type: String, trim: true }, // payment gateway reference/intent id
    paymentUrl: { type: String, trim: true },  // hosted payment page if applicable
    expiresAtISO: { type: String, trim: true } // ISO 8601 expiry
  },
  { _id: false }
);

/**
 * Driver and vehicle details (denormalized for fast reads).
 */
const driverSchema = new Schema(
  {
    name: { type: String, trim: true },
    phone: { type: String, trim: true },
    rating: { type: Number, min: 0, max: 5 },
    photo: { type: String, trim: true },
    licenseNo: { type: String, trim: true }
  },
  { _id: false }
);

const vehicleSchema = new Schema(
  {
    make: { type: String, trim: true },
    model: { type: String, trim: true },
    color: { type: String, trim: true },
    plate: { type: String, trim: true },
    classCode: { type: String, trim: true }, // MINI, SEDAN, SUV, XL, LUX, etc.
    capacity: { type: Number, min: 1 }
  },
  { _id: false }
);

/**
 * Live tracking snapshot for current position.
 */
const liveSnapshotSchema = new Schema(
  {
    lat: { type: Number },
    lng: { type: Number },
    heading: { type: Number, min: 0, max: 359 },
    speedKph: { type: Number, min: 0 },
    lastUpdatedISO: { type: String, trim: true } // ISO 8601
  },
  { _id: false }
);

const CabSchema = new Schema(
  {
    // Ownership
    userId: { type: Schema.Types.ObjectId, ref: 'User', index: true },

    // Provider and product
    provider: { type: String, required: true, trim: true, index: true }, // e.g., UBER, OLA, LOCAL_TAXI
    classCode: { type: String, required: true, trim: true, index: true }, // MINI, SEDAN, SUV, XL, etc.

    // Ride identifiers
    rideRef: { type: String, trim: true, index: true }, // provider ride id
    bookingRef: { type: String, trim: true, index: true }, // internal booking reference

    // Pickup and drop
    pickup: {
      address: addressSchema,
      location: { type: pointSchema, required: true, index: '2dsphere' },
      whenISO: { type: String, trim: true } // requested pickup time (ISO 8601)
    },
    drop: {
      address: addressSchema,
      location: { type: pointSchema, required: true, index: '2dsphere' }
    },

    // Optional intermediate waypoints
    waypoints: [
      {
        address: addressSchema,
        location: { type: pointSchema, required: true }
      }
    ],

    // Planned/actual route geometry
    route: { type: lineStringSchema, index: '2dsphere' },

    // Status lifecycle
    status: {
      type: String,
      enum: [
        'created',
        'pending_payment',
        'confirmed',
        'driver_assigned',
        'en_route_pickup',
        'arrived_pickup',
        'in_ride',
        'completed',
        'cancelled',
        'failed'
      ],
      default: 'created',
      index: true
    },
    stage: { type: String, trim: true }, // optional finer-grained stage text

    // Time tracking (ISO 8601 strings for cross-timezone clarity)
    createdISO: { type: String, trim: true },
    confirmedISO: { type: String, trim: true },
    driverAssignedISO: { type: String, trim: true },
    pickedUpISO: { type: String, trim: true },
    completedISO: { type: String, trim: true },
    cancelledISO: { type: String, trim: true },

    // Fare/pricing and payment
    fare: fareSchema,
    payment: paymentSchema,

    // Driver and vehicle
    driver: driverSchema,
    vehicle: vehicleSchema,

    // Live tracking/current position
    current: liveSnapshotSchema,

    // Metrics
    distancePlannedKm: { type: Number, min: 0 },
    distanceActualKm: { type: Number, min: 0 },
    durationPlannedMin: { type: Number, min: 0 },
    durationActualMin: { type: Number, min: 0 },

    // Flags
    isActive: { type: Boolean, default: true, index: true },

    // Misc
    notes: { type: String, trim: true },
    metadata: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true, // createdAt/updatedAt (ISO via toISOString when serialized)
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

// Helpful compound indexes for list/status queries and map lookups
CabSchema.index({ userId: 1, status: 1, createdAt: -1 });
CabSchema.index({ provider: 1, classCode: 1, status: 1, createdAt: -1 });
CabSchema.index({ 'pickup.location': '2dsphere' });
CabSchema.index({ 'drop.location': '2dsphere' });
CabSchema.index({ route: '2dsphere' });

// Virtual helpers
CabSchema.virtual('isPaid').get(function () {
  return this.payment?.status === 'captured' || this.payment?.status === 'authorized';
});

CabSchema.methods.toRideGeoJSON = function () {
  const features = [];
  // Route
  if (this.route?.type === 'LineString' && Array.isArray(this.route.coordinates)) {
    features.push({
      type: 'Feature',
      geometry: this.route,
      properties: { kind: 'cab_route', rideId: this._id }
    });
  }
  // Current position
  if (this.current?.lat != null && this.current?.lng != null) {
    features.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [this.current.lng, this.current.lat] },
      properties: {
        kind: 'vehicle_position',
        rideId: this._id,
        heading: this.current.heading || null,
        speedKph: this.current.speedKph || null,
        lastUpdatedISO: this.current.lastUpdatedISO || null,
        geo: `geo:${this.current.lat},${this.current.lng}`
      }
    });
  }
  return { type: 'FeatureCollection', features };
};

module.exports = mongoose.model('Cab', CabSchema);
