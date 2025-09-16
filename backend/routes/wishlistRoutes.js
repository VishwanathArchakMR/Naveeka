// backend/routes/wishlistRoutes.js
const express = require('express');
const { body, param, validationResult } = require('express-validator');
const Wishlist = require('../models/wishlist');
const Place = require('../models/place');
const { protect } = require('../middleware/auth');

const router = express.Router();

// Common validation error handler
const handleValidationErrors = (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array(),
    });
    return true;
  }
  return false;
};

// ---------------- GET AUTH USER WISHLIST ----------------
router.get('/', protect, async (req, res) => {
  try {
    const wishlist = await Wishlist.getUserWishlist(req.user._id);
    res.json({ success: true, data: wishlist });
  } catch (error) {
    console.error('Get wishlist error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ---------------- ADD PLACE TO WISHLIST ----------------
router.post(
  '/',
  protect,
  [
    body('placeId').isMongoId().withMessage('Invalid place ID'),
    body('notes').optional().isString().isLength({ max: 500 }).withMessage('Notes must be a string up to 500 chars')
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const { placeId, notes = '' } = req.body;

      // Validate place exists
      const place = await Place.findById(placeId);
      if (!place) {
        return res.status(404).json({ success: false, message: 'Place not found' });
      }

      // Add to wishlist (model handles upsert)
      const wishlistItem = await Wishlist.addToWishlist(req.user._id, placeId, notes);
      await wishlistItem.populate('placeId', 'name category emotion coverImage location rating price');

      res.status(201).json({
        success: true,
        message: 'Place added to wishlist',
        data: wishlistItem
      });
    } catch (error) {
      if (error && error.code === 11000) {
        // Unique index (userId+placeId) race: return existing
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
          // fall-through
        }
      }
      console.error('Add to wishlist error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- REMOVE FROM WISHLIST ----------------
router.delete(
  '/:placeId',
  protect,
  [param('placeId').isMongoId().withMessage('Invalid place ID')],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const wishlistItem = await Wishlist.findOne({
        userId: req.user._id,
        placeId: req.params.placeId
      });

      if (!wishlistItem) {
        return res.status(404).json({ success: false, message: 'Place not found in wishlist' });
      }

      await Wishlist.removeFromWishlist(req.user._id, req.params.placeId);

      res.json({ success: true, message: 'Place removed from wishlist' });
    } catch (error) {
      console.error('Remove from wishlist error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- CHECK IF PLACE IS IN WISHLIST ----------------
router.get(
  '/check/:placeId',
  protect,
  [param('placeId').isMongoId().withMessage('Invalid place ID')],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const isInWishlist = await Wishlist.isInWishlist(req.user._id, req.params.placeId);
      res.json({ success: true, data: { isInWishlist: !!isInWishlist } });
    } catch (error) {
      console.error('Check wishlist error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- UPDATE WISHLIST ITEM NOTES ----------------
router.put(
  '/:placeId',
  protect,
  [
    param('placeId').isMongoId().withMessage('Invalid place ID'),
    body('notes').optional().isString().isLength({ max: 500 }).withMessage('Notes must be a string up to 500 chars')
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const wishlistItem = await Wishlist.findOne({
        userId: req.user._id,
        placeId: req.params.placeId
      });

      if (!wishlistItem) {
        return res.status(404).json({ success: false, message: 'Place not found in wishlist' });
      }

      wishlistItem.notes = req.body.notes || '';
      await wishlistItem.save();
      await wishlistItem.populate('placeId', 'name category emotion coverImage location rating price');

      res.json({
        success: true,
        message: 'Wishlist notes updated',
        data: wishlistItem
      });
    } catch (error) {
      console.error('Update wishlist error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- CLEAR ENTIRE WISHLIST ----------------
router.delete('/', protect, async (req, res) => {
  try {
    await Wishlist.deleteMany({ userId: req.user._id });
    res.json({ success: true, message: 'Wishlist cleared successfully' });
  } catch (error) {
    console.error('Clear wishlist error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;

/*
APIs touched here:
- GET /api/wishlist
- POST /api/wishlist
- DELETE /api/wishlist/:placeId
- GET /api/wishlist/check/:placeId
- PUT /api/wishlist/:placeId
- DELETE /api/wishlist

MongoDB integration:
- Uses Wishlist model statics (getUserWishlist, addToWishlist, isInWishlist, removeFromWishlist).
- Validates ObjectId params to avoid CastErrors early.
- Enforces notes length consistent with schema (max 500).
*/
