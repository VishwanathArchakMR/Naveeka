// backend/models/social/Follow.js
const mongoose = require('mongoose');

const followSchema = new mongoose.Schema({
  followerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true }, // who follows
  followeeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true }, // who is being followed
  createdAt: { type: Date, default: Date.now }
});

// Prevent duplicate follow edges
followSchema.index({ followerId: 1, followeeId: 1 }, { unique: true });

// Fast queries: list followers of X, list who Y follows
followSchema.index({ followeeId: 1, createdAt: -1 });
followSchema.index({ followerId: 1, createdAt: -1 });

module.exports = mongoose.model('Follow', followSchema);
