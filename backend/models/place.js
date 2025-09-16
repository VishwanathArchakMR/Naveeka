// backend/models/place.js
const mongoose = require('mongoose');

// Comment / review schema
const commentSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  userName: {
    type: String,
    required: true,
    trim: true
  },
  text: {
    type: String,
    required: true,
    trim: true,
    maxlength: 1000
  },
  rating: {
    // Make 0 allowed if unrated comments can exist; else set min:1 and no default
    type: Number,
    min: 0,
    max: 5,
    default: 0
  },
  images: [{
    type: String,
    trim: true
  }],
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// Main place schema
const placeSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Place name is required'],
    trim: true,
    maxlength: 100
  },
  category: {
    type: String,
    required: [true, 'Category is required'],
    enum: ['Temples', 'Peaceful', 'Adventure', 'Heritage', 'Nature', 'Stay Places']
  },
  emotion: {
    type: String,
    required: [true, 'Emotional tag is required'],
    enum: ['Spiritual', 'Peaceful', 'Adventure', 'Nature', 'Heritage']
  },
  description: {
    type: String,
    required: [true, 'Description is required'],
    trim: true,
    maxlength: 2000
  },
  history: {
    type: String,
    trim: true,
    maxlength: 2000
  },
  coverImage: {
    type: String,
    required: [true, 'Cover image is required'],
    trim: true
  },
  gallery: [{
    type: String,
    trim: true
  }],
  phone: {
    type: String,
    trim: true
  },
  email: {
    type: String,
    trim: true,
    lowercase: true,
    match: [/^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,})+$/, 'Please enter a valid email']
  },
  timings: {
    type: String,
    trim: true
  },
  rating: {
    type: Number,
    min: 0,
    max: 5,
    default: 0
  },
  reviewCount: {
    type: Number,
    default: 0
  },
  price: {
    type: Number,
    min: 0,
    default: 0
  },

  // Backward compatibility: accept lat/lng input but store as GeoJSON Point
  // External API may still send/receive { location: { lat, lng } }
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
      required: true
    },
    coordinates: {
      // [lng, lat]
      type: [Number],
      required: true,
      validate: {
        validator: function (v) {
          return Array.isArray(v) && v.length === 2 && v.every(n => typeof n === 'number');
        },
        message: 'coordinates must be [lng, lat]'
      }
    }
  },

  reactions: [{
    type: String,
    trim: true
  }],
  comments: [commentSchema],
  
  // Legacy region path (keep for backward compatibility)
  regionPath: {
    type: String,
    required: [true, 'Region path is required'],
    trim: true
  },

  // NEW: Structured region references for hierarchical browsing
  regionRef: {
    country: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: 'Region', 
      default: null 
    },
    state: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: 'Region', 
      default: null 
    },
    district: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: 'Region', 
      default: null 
    },
    taluk: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: 'Region', 
      default: null 
    },
    town: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: 'Region', 
      default: null 
    },
    village: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: 'Region', 
      default: null 
    }
  },

  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },

  // Moderation and lifecycle
  isApproved: {
    type: Boolean,
    default: false
  },
  approvedAt: {
    type: Date
  },
  approvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  moderationNotes: {
    type: String,
    trim: true,
    maxlength: 1000
  },

  isActive: {
    type: Boolean,
    default: true
  },
  featured: {
    type: Boolean,
    default: false
  },
  tags: [{
    type: String,
    trim: true
  }],
  amenities: [{
    type: String,
    trim: true
  }],
  bestTimeToVisit: {
    type: String,
    trim: true
  },
  entryFee: {
    type: Number,
    min: 0,
    default: 0
  },
  parkingAvailable: {
    type: Boolean,
    default: false
  },
  wheelchairAccessible: {
    type: Boolean,
    default: false
  },
  petFriendly: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Virtual lat/lng for serialization (keep external compatibility)
placeSchema.virtual('location.lat').get(function () {
  return Array.isArray(this.location?.coordinates) ? this.location.coordinates[1] : undefined;
});

// FIXED: Return coordinates[0] instead of the whole array
placeSchema.virtual('location.lng').get(function () {
  return Array.isArray(this.location?.coordinates) ? this.location.coordinates[0] : undefined;
});

// Helper to set coordinates from lat/lng shape if provided in input
function normalizeLocation(doc) {
  if (doc && doc.location && typeof doc.location === 'object') {
    const hasLatLng = Object.prototype.hasOwnProperty.call(doc.location, 'lat') &&
                      Object.prototype.hasOwnProperty.call(doc.location, 'lng');
    const hasCoordinates = Array.isArray(doc.location.coordinates) && doc.location.coordinates.length === 2;

    if (hasLatLng && !hasCoordinates) {
      const { lat, lng } = doc.location;
      if (typeof lat === 'number' && typeof lng === 'number') {
        doc.location = { type: 'Point', coordinates: [lng, lat] };
      }
    }
  }
}

// Mongoose middleware to normalize incoming location on create/update
placeSchema.pre('validate', function (next) {
  try {
    normalizeLocation(this);
    next();
  } catch (e) {
    next(e);
  }
});

// Indexes (performance) - EXISTING + NEW region indexes
placeSchema.index({ name: 'text', description: 'text' });
placeSchema.index({ category: 1 });
placeSchema.index({ emotion: 1 });
placeSchema.index({ regionPath: 1 }); // Keep existing
placeSchema.index({ location: '2dsphere' });
placeSchema.index({ rating: -1 });
placeSchema.index({ createdAt: -1 });
placeSchema.index({ isApproved: 1, isActive: 1 });

// NEW: Structured region indexes for fast hierarchical queries
placeSchema.index({ 'regionRef.country': 1 });
placeSchema.index({ 'regionRef.state': 1 });
placeSchema.index({ 'regionRef.district': 1 });
placeSchema.index({ 'regionRef.taluk': 1 });
placeSchema.index({ 'regionRef.town': 1 });
placeSchema.index({ 'regionRef.village': 1 });

// Virtual: averageRating
placeSchema.virtual('averageRating').get(function () {
  if (!this.comments || this.comments.length === 0) return 0;
  const totalRating = this.comments.reduce((sum, c) => sum + (c.rating || 0), 0);
  return Math.round((totalRating / this.comments.length) * 10) / 10;
});

// Pre-save: update rating/review count automatically
placeSchema.pre('save', function (next) {
  this.rating = this.averageRating;
  this.reviewCount = this.comments.length;
  next();
});

// Statics (keep existing + add region-aware methods)
placeSchema.statics.findByCategory = function (category) {
  return this.find({ category, isApproved: true, isActive: true });
};

placeSchema.statics.findByEmotion = function (emotion) {
  return this.find({ emotion, isApproved: true, isActive: true });
};

placeSchema.statics.findByRegion = function (region) {
  return this.find({
    regionPath: { $regex: region, $options: 'i' },
    isApproved: true,
    isActive: true
  });
};

// NEW: Find by structured region (any level)
placeSchema.statics.findByRegionRef = function (regionId, level = null) {
  const filter = { isApproved: true, isActive: true };
  
  if (level) {
    // Search specific level: country, state, district, taluk, town, village
    filter[`regionRef.${level}`] = regionId;
  } else {
    // Search all levels for this region
    filter.$or = [
      { 'regionRef.country': regionId },
      { 'regionRef.state': regionId },
      { 'regionRef.district': regionId },
      { 'regionRef.taluk': regionId },
      { 'regionRef.town': regionId },
      { 'regionRef.village': regionId }
    ];
  }
  
  return this.find(filter);
};

placeSchema.statics.search = function (query) {
  return this.find({
    isApproved: true,
    isActive: true,
    $or: [
      { name: { $regex: query, $options: 'i' } },
      { description: { $regex: query, $options: 'i' } },
      { category: { $regex: query, $options: 'i' } },
      { emotion: { $regex: query, $options: 'i' } },
      { tags: { $in: [new RegExp(query, 'i')] } }
    ]
  });
};

// Instance methods
placeSchema.methods.addComment = function (commentData) {
  this.comments.push(commentData);
  return this.save();
};

placeSchema.methods.updateRating = function () {
  this.rating = this.averageRating;
  this.reviewCount = this.comments.length;
  return this.save();
};

module.exports = mongoose.model('Place', placeSchema);

/*
APIs and MongoDB integration notes:
- Backward-compatible location:
  - Accepts incoming { location: { lat, lng } } and stores as GeoJSON { type:'Point', coordinates:[lng,lat] }.
  - Exposes virtual getters so API clients still see lat/lng in responses.
  - FIXED: location.lng virtual now returns coordinates[0] instead of whole array.
  - 2dsphere index enabled for future "near me" queries.

- NEW: Structured region support:
  - regionRef contains ObjectId references to Region nodes at each level.
  - Indexes added for fast hierarchical queries.
  - findByRegionRef() static method for structured region filtering.
  - regionPath kept for backward compatibility.

- Moderation audit fields:
  - approvedAt, approvedBy (ref User), moderationNotes added for admin workflows.
  - Approve endpoints should set these when toggling isApproved.

- Ratings:
  - averageRating virtual and pre-save hook maintain rating/reviewCount.
  - Comment rating min set to 0 with default 0 for flexibility; adjust if you want to require >=1.

- Indexes:
  - Text search on name/description; single-field and 2dsphere indexes remain for performance.
  - NEW: regionRef.* indexes for hierarchical region queries.
*/
