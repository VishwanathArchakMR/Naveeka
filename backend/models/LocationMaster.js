// backend/models/LocationMaster.js

const mongoose = require('mongoose');

const { Schema } = mongoose;

// Simple slugify util (no external dep)
function toSlug(s) {
  return (s || '')
    .toString()
    .trim()
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '') // strip diacritics
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 120);
}

/**
 * GeoJSON Point schema
 * IMPORTANT: coordinates must be [lng, lat] per GeoJSON/MongoDB. [web:6980][web:6993]
 */
const pointSchema = new Schema(
  {
    type: {
      type: String,
      enum: ['Point'],
      required: true,
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: true,
      validate: {
        validator: function (arr) {
          if (!Array.isArray(arr) || arr.length !== 2) return false;
          const [lng, lat] = arr;
          return (
            typeof lng === 'number' &&
            typeof lat === 'number' &&
            lng >= -180 &&
            lng <= 180 &&
            lat >= -90 &&
            lat <= 90
          );
        },
        message: 'coordinates must be [lng, lat] with valid ranges',
      },
    },
  },
  { _id: false }
);

/**
 * LocationMaster schema
 * Represents a place/location with metadata, address, tags, rating, and geo fields. [web:6991][web:6994]
 */
const locationMasterSchema = new Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 200 },
    slug: { type: String, index: true, unique: true, sparse: true },

    type: {
      type: String,
      enum: ['country', 'state', 'city', 'area', 'place'],
      default: 'place',
      index: true,
    },

    address: {
      line1: { type: String, trim: true },
      line2: { type: String, trim: true },
      locality: { type: String, trim: true },
      landmark: { type: String, trim: true },
      city: { type: String, trim: true, index: true },
      state: { type: String, trim: true, index: true },
      country: { type: String, trim: true, index: true },
      postalCode: { type: String, trim: true, index: true },
    },

    contact: {
      phone: { type: String, trim: true },
      email: { type: String, trim: true },
      website: { type: String, trim: true },
      whatsapp: { type: String, trim: true },
      instagram: { type: String, trim: true },
      facebook: { type: String, trim: true },
      twitter: { type: String, trim: true },
    },

    openingHours: { type: String, trim: true },

    // Accessibility flags (matches frontend)
    accessibility: {
      wheelchairAccessible: { type: Boolean },
      accessibleParking: { type: Boolean },
      accessibleRestroom: { type: Boolean },
      elevator: { type: Boolean },
      brailleMenu: { type: Boolean },
      signLanguage: { type: Boolean },
      serviceAnimalsAllowed: { type: Boolean },
      familyFriendly: { type: Boolean },
      smokeFree: { type: Boolean },
      hearingLoop: { type: Boolean },
      highContrast: { type: Boolean },
      largePrint: { type: Boolean },
    },

    // Emotion/UX tags and categories
    category: { type: String, trim: true, index: true },
    emotion: { type: String, trim: true, index: true },
    tags: { type: [String], default: [], index: true },

    // Ratings
    rating: { type: Number, min: 0, max: 5, default: 0 },
    reviewsCount: { type: Number, min: 0, default: 0 },

    // Approval/workflow
    isApproved: { type: Boolean, default: false, index: true },
    isActive: { type: Boolean, default: true, index: true },

    // Primary geo point
    location: {
      type: pointSchema,
      required: true,
      index: '2dsphere', // geospatial index for $near / $geoWithin queries [web:6980][web:6979]
    },

    // Optional polygon boundary for places/areas (no strict validation here)
    boundary: {
      type: {
        type: String,
        enum: ['Polygon', 'MultiPolygon'],
      },
      coordinates: {
        type: Array,
      },
    },

    // Misc identifiers
    externalIds: {
      googlePlaceId: { type: String, index: true },
      osmId: { type: String, index: true },
    },

    media: {
      coverImage: { type: String, trim: true },
      photos: { type: [String], default: [] },
    },

    createdBy: { type: Schema.Types.ObjectId, ref: 'User', index: true },
    updatedBy: { type: Schema.Types.ObjectId, ref: 'User', index: true },
  },
  {
    timestamps: true,
    collection: 'location_masters',
  }
);

/**
 * Indexes
 * - 2dsphere on `location` enables geospatial queries ($near, $geoWithin) [web:6980][web:6995]
 * - text index for search across name, address, and tags (one text index per collection) [web:6998][web:6985]
 */
locationMasterSchema.index({ location: '2dsphere' }); // redundant with path-level index but safe for clarity [web:6980][web:6979]

// Single text index including multiple fields with weights
locationMasterSchema.index(
  {
    name: 'text',
    'address.line1': 'text',
    'address.line2': 'text',
    'address.locality': 'text',
    'address.city': 'text',
    'address.state': 'text',
    'address.country': 'text',
    category: 'text',
    emotion: 'text',
    // tags as text via $** alternative is possible but explicit is clearer
  },
  {
    weights: {
      name: 10,
      category: 6,
      emotion: 4,
      'address.city': 4,
      'address.state': 3,
      'address.country': 2,
    },
    name: 'location_text_idx',
    default_language: 'english',
  }
); // Only one text index per collection, combine fields as above [web:6998][web:6985]

/**
 * Pre-save: ensure slug from name if missing or changed
 */
locationMasterSchema.pre('save', function (next) {
  if (this.isModified('name') || !this.slug) {
    this.slug = toSlug(this.name);
  }
  next();
});

/**
 * Static helpers
 */

// Find nearby locations within radiusKm (uses $near on 2dsphere index)
locationMasterSchema.statics.findNearby = function findNearby({
  lng,
  lat,
  radiusKm = 5,
  filter = {},
  limit = 50,
  projection = null,
  sort = null,
}) {
  // $near requires 2dsphere index and [lng, lat] order [web:6995][web:6980]
  const meters = Math.max(0, Number(radiusKm)) * 1000;
  const query = {
    ...filter,
    location: {
      $near: {
        $geometry: { type: 'Point', coordinates: [lng, lat] },
        $maxDistance: meters,
      },
    },
  };
  let q = this.find(query, projection).limit(Math.min(200, Math.max(1, limit)));
  if (sort) q = q.sort(sort);
  return q;
};

// Text search with score
locationMasterSchema.statics.search = function search(q, { limit = 50, filter = {}, projection = null } = {}) {
  const text = (q || '').toString().trim();
  if (!text) {
    return this.find(filter, projection).limit(Math.min(200, Math.max(1, limit)));
  }
  return this.find(
    { $text: { $search: text }, ...filter },
    { score: { $meta: 'textScore' }, ...(projection || {}) }
  )
    .sort({ score: { $meta: 'textScore' } })
    .limit(Math.min(200, Math.max(1, limit)));
};

const LocationMaster = mongoose.models.LocationMaster || mongoose.model('LocationMaster', locationMasterSchema);

module.exports = LocationMaster;
