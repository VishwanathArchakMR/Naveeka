// C:\flutterapp\myapp\backend\models\TripGroup.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON Point [lng, lat] with bounds validation for itinerary POIs.
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
 * Roles map: { userIdString: 'admin'|'member'|'viewer' }.
 * Stored as a plain object for quick authorization checks.
 */
const rolesSchema = new Schema({}, { _id: false, strict: false });

/**
 * Itinerary item aligned with controllers: ISO 8601 times and optional location.
 */
const itineraryItemSchema = new Schema(
  {
    _id: { type: Schema.Types.ObjectId, auto: true },
    dayOffset: { type: Number, min: 0, default: 0, index: true }, // 0-based offset from startDate
    seq: { type: Number, min: 0, default: 0, index: true },
    title: { type: String, required: true, trim: true },
    type: { type: String, trim: true, index: true },        // place|activity|food|transport|custom
    entityType: { type: String, trim: true },               // optional cross-link type
    entityId: { type: Schema.Types.ObjectId },              // optional cross-link id
    startISO: { type: String, trim: true },                 // ISO 8601 start
    endISO: { type: String, trim: true },                   // ISO 8601 end
    durationMin: { type: Number, min: 0 },                  // convenience cache
    location: { type: pointSchema },                        // optional map pin
    address: {
      line1: { type: String, trim: true },
      line2: { type: String, trim: true },
      city: { type: String, trim: true, index: true },
      state: { type: String, trim: true },
      country: { type: String, trim: true, index: true },
      postalCode: { type: String, trim: true }
    },
    notes: { type: String, trim: true },
    tags: [{ type: String, trim: true, index: true }],
    photos: [{ type: String, trim: true }],
    meta: { type: Schema.Types.Mixed }
  },
  { _id: false }
);

/**
 * Budget expense with simple split info.
 */
const expenseSchema = new Schema(
  {
    _id: { type: Schema.Types.ObjectId, auto: true },
    title: { type: String, required: true, trim: true },
    amount: { type: Number, min: 0, required: true },
    currency: { type: String, trim: true, required: true },
    category: { type: String, trim: true, index: true },         // stay|food|transport|activity|misc
    paidBy: { type: Schema.Types.ObjectId, ref: 'User', index: true },
    split: {
      type: { type: String, enum: ['equal', 'percentage', 'shares', 'exact'], default: 'equal' },
      shares: [{ userId: { type: Schema.Types.ObjectId, ref: 'User' }, value: { type: Number } }]
    },
    occurredAtISO: { type: String, trim: true },                 // ISO 8601
    notes: { type: String, trim: true },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User' },
    updatedBy: { type: Schema.Types.ObjectId, ref: 'User' }
  },
  { _id: false, timestamps: true }
);

/**
 * Checklist item with assignees and due date.
 */
const checklistItemSchema = new Schema(
  {
    _id: { type: Schema.Types.ObjectId, auto: true },
    title: { type: String, required: true, trim: true },
    done: { type: Boolean, default: false, index: true },
    dueISO: { type: String, trim: true },                         // ISO 8601 (optional)
    assignees: [{ type: Schema.Types.ObjectId, ref: 'User', index: true }],
    createdBy: { type: Schema.Types.ObjectId, ref: 'User' },
    completedAt: { type: Date }
  },
  { _id: false, timestamps: true }
);

/**
 * Document entry for group file storage.
 */
const documentSchema = new Schema(
  {
    _id: { type: Schema.Types.ObjectId, auto: true },
    key: { type: String, required: true, trim: true, index: true }, // storage key
    name: { type: String, trim: true },
    mime: { type: String, trim: true },
    size: { type: Number, min: 0 },
    url: { type: String, trim: true },                              // signed/public URL
    uploadedBy: { type: Schema.Types.ObjectId, ref: 'User', index: true },
    uploadedAt: { type: Date, default: () => new Date(), index: true }
  },
  { _id: false }
);

const TripGroupSchema = new Schema(
  {
    // Identity and ownership
    name: { type: String, required: true, trim: true, index: true },
    slug: { type: String, trim: true, index: true },
    cover: { type: String, trim: true },

    ownerId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    members: [{ type: Schema.Types.ObjectId, ref: 'User', index: true }],
    roles: { type: rolesSchema, default: {} }, // { userId: 'admin'|'member'|'viewer' }

    // Schedule boundaries (ISO-friendly Date fields)
    startDate: { type: Date, index: true },
    endDate: { type: Date, index: true },

    // Settings and destination
    settings: {
      destination: { type: String, trim: true, index: true },
      currency: { type: String, trim: true },   // default currency for budget
      tz: { type: String, trim: true }          // group timezone (IANA)
    },

    // Itinerary, budget, checklist, documents
    itinerary: { type: [itineraryItemSchema], default: [] },
    budget: {
      baseCurrency: { type: String, trim: true },
      expenses: { type: [expenseSchema], default: [] }
    },
    checklist: { type: [checklistItemSchema], default: [] },
    documents: { type: [documentSchema], default: [] },

    // Engagement
    likesCount: { type: Number, min: 0, default: 0 },
    viewCount: { type: Number, min: 0, default: 0 },
    popularity: { type: Number, min: 0, default: 0 },

    // Flags
    isActive: { type: Boolean, default: true, index: true },

    // Misc
    metadata: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true,                  // createdAt, updatedAt
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

/**
 * Indexes
 */
// Search across key fields
TripGroupSchema.index(
  { name: 'text', 'settings.destination': 'text' },
  { name: 'trip_group_text_idx', weights: { name: 8, 'settings.destination': 5 } }
);

// Membership and recency
TripGroupSchema.index({ ownerId: 1, updatedAt: -1 });
TripGroupSchema.index({ members: 1, updatedAt: -1 });
TripGroupSchema.index({ isActive: 1, popularity: -1, viewCount: -1 });

// Itinerary spatial queries and day/filter lookups
TripGroupSchema.index({ 'itinerary.location': '2dsphere' }); // map/nearby overlays [21]
TripGroupSchema.index({ 'itinerary.dayOffset': 1, 'itinerary.seq': 1 });
TripGroupSchema.index({ 'budget.expenses.category': 1, 'budget.expenses.createdAt': -1 });
TripGroupSchema.index({ 'checklist.done': 1, 'checklist.updatedAt': -1 });
TripGroupSchema.index({ 'documents.uploadedAt': -1 });

/**
 * Hooks
 */
TripGroupSchema.pre('save', function (next) {
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
 * Virtuals
 */
TripGroupSchema.virtual('memberCount').get(function () {
  return Array.isArray(this.members) ? this.members.length : 0;
});

/**
 * Helpers
 */
TripGroupSchema.methods.toPreview = function () {
  return {
    id: this._id,
    name: this.name,
    cover: this.cover || null,
    destination: this.settings?.destination || null,
    startDate: this.startDate || null,
    endDate: this.endDate || null,
    memberCount: this.memberCount,
    popularity: this.popularity || 0,
    updatedAt: this.updatedAt
  };
};

module.exports = mongoose.model('TripGroup', TripGroupSchema);
