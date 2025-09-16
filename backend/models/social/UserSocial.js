// backend/models/social/UserSocial.js
const mongoose = require('mongoose');

const userSocialSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', unique: true, required: true, index: true }, // 1:1 with User for social data [web:87][web:85]
  handle: { type: String, required: true, trim: true, lowercase: true, unique: true, index: true }, // public @handle for profile and mentions [web:87][web:81]
  name: { type: String, trim: true, maxlength: 100 }, // display name override if needed [web:87]
  bio: { type: String, trim: true, maxlength: 200 }, // short bio for profile [web:71]
  avatar: { type: String, trim: true }, // profile image URL (Cloudinary or similar) [web:89]
  links: [{ type: String, trim: true }], // external links (youtube, instagram, website) [web:71]
  preferences: [{ type: String, trim: true }], // travel interests to influence feeds [web:82]
  locationText: { type: String, trim: true }, // optional city/country text label [web:71]
  counts: {
    followers: { type: Number, default: 0 },
    following: { type: Number, default: 0 },
    posts: { type: Number, default: 0 }
  }, // cached counters for quick UI [web:72]
  isVerified: { type: Boolean, default: false }, // verification badge [web:71]
  isActive: { type: Boolean, default: true } // soft-disable profile if needed [web:87]
}, { timestamps: true });

userSocialSchema.index({ createdAt: -1 }); // recent creators listing [web:82]

// Helper to safely expose public profile fields
userSocialSchema.methods.toPublicJSON = function () {
  return {
    id: this._id,
    handle: this.handle,
    name: this.name,
    bio: this.bio,
    avatar: this.avatar,
    links: this.links,
    counts: this.counts,
    isVerified: this.isVerified,
  };
}; // minimal public projection for feeds/direct profile fetch [web:87]

module.exports = mongoose.model('UserSocial', userSocialSchema);
