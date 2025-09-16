// backend/routes/userRoutes.js
const express = require('express');
const { body, validationResult, query, param } = require('express-validator');
const User = require('../models/user');
const Place = require('../models/place');
const Wishlist = require('../models/wishlist');
const { protect, admin } = require('../middleware/auth');

const router = express.Router();

// Helper: handle validation errors centrally
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

// ---------------- GET ALL USERS (ADMIN) ----------------
router.get(
  '/',
  admin,
  [
    query('role').optional().isIn(['user', 'partner', 'admin']),
    query('isActive').optional().isBoolean().toBoolean(),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const { role, isActive } = req.query;
      const page = req.query.page || 1;
      const limit = req.query.limit || 20;

      const filter = {};
      if (role) filter.role = role;
      if (typeof isActive === 'boolean') filter.isActive = isActive;

      const skip = (page - 1) * limit;
      const users = await User.find(filter)
        .select('-password')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit);

      const total = await User.countDocuments(filter);

      res.json({
        success: true,
        data: users,
        pagination: {
          current: page,
          total: Math.ceil(total / limit),
          hasNext: skip + users.length < total,
          hasPrev: page > 1
        }
      });
    } catch (error) {
      console.error('Get users error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- GET USER BY ID ----------------
router.get(
  '/:id',
  protect,
  [param('id').isMongoId().withMessage('Invalid user id')],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      if (req.user.role !== 'admin' && req.user._id.toString() !== req.params.id) {
        return res.status(403).json({ success: false, message: 'Not authorized' });
      }

      const user = await User.findById(req.params.id).select('-password');
      if (!user) return res.status(404).json({ success: false, message: 'User not found' });

      res.json({ success: true, data: user });
    } catch (error) {
      console.error('Get user error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- UPDATE USER (ADMIN) ----------------
router.put(
  '/:id',
  admin,
  [
    param('id').isMongoId().withMessage('Invalid user id'),
    body('name').optional().trim().isLength({ min: 2, max: 50 }),
    body('email').optional().isEmail().normalizeEmail(),
    body('phone').optional().matches(/^[0-9]{10}$/),
    body('role').optional().isIn(['user', 'partner', 'admin']),
    body('isActive').optional().isBoolean().toBoolean(),
    body('isVerified').optional().isBoolean().toBoolean(),
    body('preferences').optional().isArray()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const update = { ...req.body, updatedAt: Date.now() };

      const user = await User.findByIdAndUpdate(
        req.params.id,
        update,
        { new: true, runValidators: true }
      ).select('-password');

      if (!user) return res.status(404).json({ success: false, message: 'User not found' });

      res.json({ success: true, message: 'User updated', data: user });
    } catch (error) {
      console.error('Update user error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- DELETE USER (ADMIN) ----------------
router.delete(
  '/:id',
  admin,
  [param('id').isMongoId().withMessage('Invalid user id')],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const user = await User.findById(req.params.id);
      if (!user) return res.status(404).json({ success: false, message: 'User not found' });

      if (user._id.toString() === req.user._id.toString()) {
        return res.status(400).json({ success: false, message: 'Cannot delete your own account' });
      }

      await User.findByIdAndDelete(req.params.id);
      res.json({ success: true, message: 'User deleted' });
    } catch (error) {
      console.error('Delete user error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- GET USER STATS ----------------
router.get(
  '/:id/stats',
  protect,
  [param('id').isMongoId().withMessage('Invalid user id')],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      if (req.user.role !== 'admin' && req.user._id.toString() !== req.params.id) {
        return res.status(403).json({ success: false, message: 'Not authorized' });
      }

      const userId = req.params.id;

      const placesCount = await Place.countDocuments({ createdBy: userId });
      const wishlistCount = await Wishlist.countDocuments({ userId });

      // Count only this user's comments using unwind+match
      const commentsAgg = await Place.aggregate([
        { $unwind: '$comments' },
        { $match: { 'comments.userId': new (require('mongoose')).Types.ObjectId(userId) } },
        { $count: 'total' }
      ]);
      const commentsCount = commentsAgg[0]?.total || 0;

      const avgAgg = await Place.aggregate([
        { $unwind: '$comments' },
        { $match: { 'comments.userId': new (require('mongoose')).Types.ObjectId(userId) } },
        { $group: { _id: null, avgRating: { $avg: '$comments.rating' } } }
      ]);
      const avgRating = avgAgg[0]?.avgRating || 0;

      res.json({
        success: true,
        data: {
          placesCount,
          wishlistCount,
          commentsCount,
          avgRating
        }
      });
    } catch (error) {
      console.error('Get user stats error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- GET USER PLACES ----------------
router.get(
  '/:id/places',
  protect,
  [
    param('id').isMongoId().withMessage('Invalid user id'),
    query('approved').optional().isBoolean().toBoolean(),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      if (req.user.role !== 'admin' && req.user._id.toString() !== req.params.id) {
        return res.status(403).json({ success: false, message: 'Not authorized' });
      }

      const page = req.query.page || 1;
      const limit = req.query.limit || 20;

      const filter = { createdBy: req.params.id };
      if (typeof req.query.approved === 'boolean') filter.isApproved = req.query.approved;

      const skip = (page - 1) * limit;

      const places = await Place.find(filter)
        .populate('createdBy', 'name')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit);

      const total = await Place.countDocuments(filter);

      res.json({
        success: true,
        data: places,
        pagination: {
          current: page,
          total: Math.ceil(total / limit),
          hasNext: skip + places.length < total,
          hasPrev: page > 1
        }
      });
    } catch (error) {
      console.error('Get user places error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- GET USER WISHLIST ----------------
router.get(
  '/:id/wishlist',
  protect,
  [
    param('id').isMongoId().withMessage('Invalid user id'),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      if (req.user.role !== 'admin' && req.user._id.toString() !== req.params.id) {
        return res.status(403).json({ success: false, message: 'Not authorized' });
      }

      const page = req.query.page || 1;
      const limit = req.query.limit || 20;
      const skip = (page - 1) * limit;

      const wishlist = await Wishlist.find({ userId: req.params.id })
        .populate('placeId', 'name category emotion coverImage location rating price')
        .sort({ addedAt: -1 })
        .skip(skip)
        .limit(limit);

      const total = await Wishlist.countDocuments({ userId: req.params.id });

      res.json({
        success: true,
        data: wishlist,
        pagination: {
          current: page,
          total: Math.ceil(total / limit),
          hasNext: skip + wishlist.length < total,
          hasPrev: page > 1
        }
      });
    } catch (error) {
      console.error('Get user wishlist error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- DASHBOARD STATS (ADMIN) ----------------
router.get('/dashboard/stats', admin, async (req, res) => {
  try {
    const totalUsers = await User.countDocuments();
    const activeUsers = await User.countDocuments({ isActive: true });
    const partners = await User.countDocuments({ role: 'partner' });
    const admins = await User.countDocuments({ role: 'admin' });

    const totalPlaces = await Place.countDocuments();
    const approvedPlaces = await Place.countDocuments({ isApproved: true });
    const pendingPlaces = await Place.countDocuments({ isApproved: false });

    const recentUsers = await User.find()
      .select('name email role createdAt')
      .sort({ createdAt: -1 })
      .limit(5);

    const recentPlaces = await Place.find()
      .populate('createdBy', 'name')
      .select('name category createdBy createdAt')
      .sort({ createdAt: -1 })
      .limit(5);

    res.json({
      success: true,
      data: {
        users: { total: totalUsers, active: activeUsers, partners, admins },
        places: { total: totalPlaces, approved: approvedPlaces, pending: pendingPlaces },
        recent: { users: recentUsers, places: recentPlaces }
      }
    });
  } catch (error) {
    console.error('Dashboard stats error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;

/*
APIs touched here:
- GET /api/users (admin; filters: role, isActive, page, limit)
- GET /api/users/:id (self or admin)
- PUT /api/users/:id (admin)
- DELETE /api/users/:id (admin; prevents self-deletion)
- GET /api/users/:id/stats (self or admin) — fixed comments counting to only this user's comments
- GET /api/users/:id/places (self or admin; filters: approved, page, limit)
- GET /api/users/:id/wishlist (self or admin; pagination)
- GET /api/users/dashboard/stats (admin)

MongoDB integration:
- Uses Place and Wishlist counts and aggregations.
- Aggregations for comments and avgRating use $unwind + $match on comments.userId.
- Query param coercion via .toBoolean()/.toInt() prevents string truthiness bugs.
*/
