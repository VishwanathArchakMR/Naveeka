// backend/models/social/Reaction.js
const mongoose = require('mongoose');
const { REACTION_KINDS } = require('../../utils/constants');

const reactionSchema = new mongoose.Schema(
  {
    postId: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', required: true, index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    kind: { type: String, enum: REACTION_KINDS, required: true } // 'like' | 'save' | 'share'
  },
  { timestamps: true }
);

// A user can react only once per kind per post
reactionSchema.index({ postId: 1, userId: 1, kind: 1 }, { unique: true }); // compound uniqueness [1]

// Extra indexes for fast queries
reactionSchema.index({ kind: 1, createdAt: -1 }); // reaction streams
reactionSchema.index({ userId: 1, createdAt: -1 }); // user's recent reactions

module.exports = mongoose.model('Reaction', reactionSchema);
