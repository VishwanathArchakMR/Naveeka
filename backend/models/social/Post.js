// backend/models/social/Post.js
const mongoose = require('mongoose');
const { POST_KINDS, VISIBILITY } = require('../../utils/constants');

// Media item embedded schema
const mediaSchema = new mongoose.Schema(
  {
    type: { type: String, enum: ['image', 'video'], required: true }, // media type
    url: { type: String, required: true, trim: true },                // file URL (e.g., Cloudinary)
    thumb: { type: String, trim: true },                              // thumbnail/preview URL
    dur: { type: Number, min: 0 }                                     // duration in seconds (for video)
  },
  { _id: false }
);

const postSchema = new mongoose.Schema(
  {
    authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    // Kind of social content
    kind: { type: String, enum: POST_KINDS, required: true, index: true }, // 'photo' | 'video' | 'reel' | 'longform'

    // Textual data
    caption: { type: String, trim: true, maxlength: 2000 },
    tags: [{ type: String, trim: true, index: true }],        // hashtags/keywords
    emotions: [{ type: String, trim: true, index: true }],    // e.g., Spiritual/Peaceful/Adventure
    categories: [{ type: String, trim: true, index: true }],  // e.g., Temples/Heritage/Nature

    // Location linkage
    placeRefs: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Place', index: true }],
    regionRefs: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Region', index: true }],

    // Media
    media: {
      type: [mediaSchema],
      validate: (arr) => Array.isArray(arr) && arr.length > 0
    },

    // Audience scope
    visibility: { type: String, enum: VISIBILITY, default: 'public', index: true },

    // Moderation and lifecycle
    isApproved: { type: Boolean, default: true }, // toggle to queue moderation later
    isActive: { type: Boolean, default: true },   // soft-delete

    // Lightweight engagement counters (denormalized)
    metrics: {
      likes: { type: Number, default: 0 },
      comments: { type: Number, default: 0 },
      shares: { type: Number, default: 0 },
      views: { type: Number, default: 0 }
    }
  },
  { timestamps: true }
);

// Useful indexes
postSchema.index({ createdAt: -1 });
postSchema.index({ authorId: 1, createdAt: -1 });
postSchema.index({ kind: 1, createdAt: -1 });
postSchema.index({ 'metrics.likes': -1, createdAt: -1 });

// Simple projection for feeds
postSchema.methods.toFeedJSON = function () {
  return {
    id: this._id,
    authorId: this.authorId,
    kind: this.kind,
    caption: this.caption,
    tags: this.tags,
    emotions: this.emotions,
    categories: this.categories,
    media: this.media,
    visibility: this.visibility,
    metrics: this.metrics,
    createdAt: this.createdAt
  };
};

module.exports = mongoose.model('Post', postSchema);
