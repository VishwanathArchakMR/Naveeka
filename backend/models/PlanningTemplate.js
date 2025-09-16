// C:\flutterapp\myapp\backend\models\PlanningTemplate.js

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
 * A single itinerary item within a day of the template. 
 * Uses ISO 8601 strings for start/end times and GeoJSON Point for an optional location. 
 */
const itemSchema = new Schema(
  {
    seq: { type: Number, min: 0, default: 0, index: true },          // ordering within the day
    title: { type: String, required: true, trim: true },              // e.g., "City Walking Tour"
    type: { type: String, trim: true, index: true },                  // e.g., place|activity|meal|transfer|custom
    entityType: { type: String, trim: true },                         // optional cross-link (place, hotel, activity, etc.)
    entityId: { type: Schema.Types.ObjectId },                        // optional cross-link id
    startISO: { type: String, trim: true },                           // ISO 8601 start (local or UTC, client-normalized)
    endISO: { type: String, trim: true },                             // ISO 8601 end (local or UTC, client-normalized)
    durationMin: { type: Number, min: 0 },                            // convenience duration cache
    location: { type: pointSchema },                                  // optional map pin
    address: {
      line1: { type: String, trim: true },
      line2: { type: String, trim: true },
      city: { type: String, trim: true, index: true },
      state: { type: String, trim: true },
      country: { type: String, trim: true, index: true },
      postalCode: { type: String, trim: true }
    },
    notes: { type: String, trim: true },                              // free-form notes
    photos: [{ type: String, trim: true }],                           // optional media references
    tags: [{ type: String, trim: true, index: true }],                // quick filters within a day
    budget: {
      amount: { type: Number, min: 0 },
      currency: { type: String, trim: true }
    },
    meta: { type: Schema.Types.Mixed }                                // provider/service hints
  },
  { _id: false }
);

/**
 * A template day grouping ordered items. 
 */
const daySchema = new Schema(
  {
    dayNumber: { type: Number, min: 1, required: true, index: true }, // 1-based day index
    title: { type: String, trim: true },                              // optional day title
    summary: { type: String, trim: true },                            // optional brief summary
    items: { type: [itemSchema], default: [] }
  },
  { _id: false }
);

const PlanningTemplateSchema = new Schema(
  {
    // Identity and visibility
    name: { type: String, required: true, trim: true, index: true },
    slug: { type: String, trim: true, index: true },
    description: { type: String, trim: true },
    cover: { type: String, trim: true },                 // cover image
    authorId: { type: Schema.Types.ObjectId, ref: 'User', index: true },
    isPublic: { type: Boolean, default: true, index: true },

    // Classification and discovery
    destination: { type: String, trim: true, index: true }, // e.g., "Rome", "Goa, India"
    tags: [{ type: String, trim: true, index: true }],      // e.g., beach, food, family, adventure
    themes: [{ type: String, trim: true, index: true }],    // e.g., honeymoon, backpacking
    days: { type: [daySchema], default: [] },               // ordered days with items

    // Aggregate hints for sorting/filtering
    totalDays: { type: Number, min: 0, index: true },
    totalBudget: {
      amount: { type: Number, min: 0 },
      currency: { type: String, trim: true }
    },

    // Engagement
    likesCount: { type: Number, min: 0, default: 0 },
    useCount: { type: Number, min: 0, default: 0 },         // how many times applied/used
    viewCount: { type: Number, min: 0, default: 0 },
    popularity: { type: Number, min: 0, default: 0 },

    // Meta
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
// Text index for search (single text index with weights)
PlanningTemplateSchema.index(
  {
    name: 'text',
    description: 'text',
    destination: 'text',
    tags: 'text',
    themes: 'text',
    'days.items.title': 'text',
    'days.items.notes': 'text'
  },
  {
    name: 'planning_template_text_idx',
    weights: {
      name: 10,
      destination: 7,
      tags: 5,
      themes: 4,
      'days.items.title': 6,
      description: 3,
      'days.items.notes': 2
    }
  }
);

// Compound indexes for common filters and sorts
PlanningTemplateSchema.index({ isPublic: 1, destination: 1, totalDays: 1, popularity: -1 });
PlanningTemplateSchema.index({ authorId: 1, createdAt: -1 });
PlanningTemplateSchema.index({ isPublic: 1, tags: 1, themes: 1, popularity: -1 });
PlanningTemplateSchema.index({ isPublic: 1, viewCount: -1, updatedAt: -1 });

// 2dsphere index for any item locations to support map/nearby in templates
PlanningTemplateSchema.index({ 'days.items.location': '2dsphere' });

/**
 * Virtuals
 */
PlanningTemplateSchema.virtual('dayCount').get(function () {
  return Array.isArray(this.days) ? this.days.length : 0;
});

/**
 * Hooks
 */
// Maintain totalDays automatically based on the days array
PlanningTemplateSchema.pre('save', function (next) {
  this.totalDays = Array.isArray(this.days) ? this.days.length : 0;
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
// Produce a lightweight JSON skeleton for previews
PlanningTemplateSchema.methods.toPreview = function () {
  return {
    id: this._id,
    name: this.name,
    slug: this.slug || null,
    cover: this.cover || null,
    destination: this.destination || null,
    tags: this.tags || [],
    themes: this.themes || [],
    totalDays: this.totalDays || 0,
    popularity: this.popularity || 0,
    isPublic: !!this.isPublic,
    updatedAt: this.updatedAt
  };
};

module.exports = mongoose.model('PlanningTemplate', PlanningTemplateSchema);
