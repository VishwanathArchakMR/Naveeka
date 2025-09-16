// backend/controllers/wishlistController.js
const mongoose = require('mongoose');
const Wishlist = require('../models/wishlist');
const Place = require('../models/place');

/**
 * Simple ObjectId guard to avoid CastErrors when routes call controllers directly
 */
const isValidObjectId = (id) => mongoose.Types.ObjectId.isValid(id);

/**
 * @desc Get wishlist (full list; pagination is available via GET /api/users/:id/wishlist)
 */
exports.getWishlist = async (req, res) => {
  try {
    const wishlist = await Wishlist.getUserWishlist(req.user._id);
    return res.json({ success: true, data: wishlist });
  } catch (err) {
    console.error('Get wishlist error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Add to wishlist
 */
exports.addToWishlist = async (req, res) => {
  try {
    const { placeId, notes = '' } = req.body;

    // Early ObjectId validation
    if (!isValidObjectId(placeId)) {
      return res.status(400).json({ success: false, message: 'Invalid place ID' });
    }

    // Validate place exists
    const place = await Place.findById(placeId);
    if (!place) {
      return res.status(404).json({ success: false, message: 'Place not found' });
    }

    // Add or update notes (upsert)
    const wishlistItem = await Wishlist.addToWishlist(req.user._id, placeId, notes);
    await wishlistItem.populate('placeId', 'name category emotion coverImage location rating price');

    return res.status(201).json({
      success: true,
      message: 'Place added to wishlist',
      data: wishlistItem
    });
  } catch (err) {
    // Handle unique constraint races gracefully (userId+placeId unique)
    if (err && err.code === 11000) {
      // Retry by fetching current item
      try {
        const item = await Wishlist.findOne({ userId: req.user._id, placeId: req.body.placeId })
          .populate('placeId', 'name category emotion coverImage location rating price');
        if (item) {
          return res.status(200).json({
            success: true,
            message: 'Place already in wishlist',
            data: item
          });
        }
      } catch (e2) {
        // fall-through to generic error
      }
    }

    console.error('Add wishlist error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Remove from wishlist
 */
exports.removeFromWishlist = async (req, res) => {
  try {
    const { placeId } = req.params;

    if (!isValidObjectId(placeId)) {
      return res.status(400).json({ success: false, message: 'Invalid place ID' });
    }

    const item = await Wishlist.findOne({ userId: req.user._id, placeId });
    if (!item) {
      return res.status(404).json({ success: false, message: 'Place not found in wishlist' });
    }

    await Wishlist.removeFromWishlist(req.user._id, placeId);
    return res.json({ success: true, message: 'Place removed from wishlist' });
  } catch (err) {
    console.error('Remove wishlist error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Check wishlist
 */
exports.checkWishlist = async (req, res) => {
  try {
    const { placeId } = req.params;

    if (!isValidObjectId(placeId)) {
      return res.status(400).json({ success: false, message: 'Invalid place ID' });
    }

    const isInWishlist = await Wishlist.isInWishlist(req.user._id, placeId);
    return res.json({ success: true, data: { isInWishlist: !!isInWishlist } });
  } catch (err) {
    console.error('Check wishlist error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Update notes
 */
exports.updateWishlistNotes = async (req, res) => {
  try {
    const { placeId } = req.params;

    if (!isValidObjectId(placeId)) {
      return res.status(400).json({ success: false, message: 'Invalid place ID' });
    }

    const item = await Wishlist.findOne({ userId: req.user._id, placeId });
    if (!item) {
      return res.status(404).json({ success: false, message: 'Place not found in wishlist' });
    }

    // Enforce max length similar to schema (500)
    const notes = typeof req.body.notes === 'string' ? req.body.notes.slice(0, 500) : '';
    item.notes = notes;
    await item.save();
    await item.populate('placeId', 'name category emotion coverImage location rating price');

    return res.json({
      success: true,
      message: 'Wishlist notes updated',
      data: item
    });
  } catch (err) {
    console.error('Update wishlist error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Clear wishlist
 */
exports.clearWishlist = async (req, res) => {
  try {
    await Wishlist.deleteMany({ userId: req.user._id });
    return res.json({ success: true, message: 'Wishlist cleared successfully' });
  } catch (err) {
    console.error('Clear wishlist error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};
