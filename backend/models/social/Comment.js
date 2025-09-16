// backend/models/social/Comment.js
const mongoose = require('mongoose');

const commentSchema = new mongoose.Schema(
  {
    postId: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', required: true, index: true }, // reverse reference for 1-to-many [2]
    authorId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    text: { type: String, required: true, trim: true, maxlength: 1000 },
    rating: { type: Number, min: 0, max: 5, default: 0 }, // optional star-style rating for travel posts
    images: [{ type: String, trim: true }], // optional image attachments
    isActive: { type: Boolean, default: true } // soft delete
  },
  { timestamps: true }
);

// Indexes for efficient listing and moderation
commentSchema.index({ postId: 1, createdAt: -1 }); // list latest comments per post [3]
commentSchema.index({ authorId: 1, createdAt: -1 });

module.exports = mongoose.model('CommentSocial', commentSchema);
