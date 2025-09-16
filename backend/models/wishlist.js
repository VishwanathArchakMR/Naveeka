// backend/models/wishlist.js
const mongoose = require('mongoose');

const wishlistSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'User ID is required']
    },
    placeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Place',
      required: [true, 'Place ID is required']
    },
    addedAt: {
      type: Date,
      default: Date.now
    },
    notes: {
      type: String,
      trim: true,
      maxlength: 500
    }
  },
  {
    timestamps: true
  }
);

// Compound index to ensure a place is saved only once per user
wishlistSchema.index({ userId: 1, placeId: 1 }, { unique: true });

// Single field indexes for faster lookups
wishlistSchema.index({ userId: 1 });
wishlistSchema.index({ placeId: 1 });

// Internal helper: coerce to ObjectId when possible (keeps API flexible)
const toObjectId = (id) => {
  try {
    return id instanceof mongoose.Types.ObjectId ? id : new mongoose.Types.ObjectId(id);
  } catch {
    return id; // let Mongoose validation surface an error if invalid
  }
};

/**
 * Get all items in a user's wishlist (populated, newest first)
 */
wishlistSchema.statics.getUserWishlist = function (userId) {
  return this.find({ userId: toObjectId(userId) })
    .populate('placeId', 'name category emotion coverImage location rating price')
    .sort({ addedAt: -1 });
};

/**
 * Check if a place is in a user's wishlist
 */
wishlistSchema.statics.isInWishlist = function (userId, placeId) {
  return this.exists({ userId: toObjectId(userId), placeId: toObjectId(placeId) });
};

/**
 * Add a place to a user's wishlist (or update notes if it already exists)
 */
wishlistSchema.statics.addToWishlist = function (userId, placeId, notes = '') {
  return this.findOneAndUpdate(
    { userId: toObjectId(userId), placeId: toObjectId(placeId) },
    { notes, addedAt: Date.now() }, // refresh timestamp on re-add
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
};

/**
 * Remove a place from a user's wishlist
 */
wishlistSchema.statics.removeFromWishlist = function (userId, placeId) {
  return this.findOneAndDelete({ userId: toObjectId(userId), placeId: toObjectId(placeId) });
};

module.exports = mongoose.model('Wishlist', wishlistSchema);

/*
APIs and MongoDB integration notes:
- Used by wishlist routes/controllers and user routes (paginated variant).
- Unique compound index { userId, placeId } prevents duplicates under race conditions.
- getUserWishlist returns populated Place fields commonly needed by the app.
- Statics accept string or ObjectId; conversion is handled internally.
*/
