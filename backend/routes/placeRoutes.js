// backend/routes/placeRoutes.js
const express = require('express');
const { body, validationResult, query, param } = require('express-validator');
const { protect, admin, partnerOrAdmin, optionalAuth } = require('../middleware/auth');
const placeController = require('../controllers/placeController');

const router = express.Router();

// Helper: centralized validation error handling (explicit boolean return)
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

// ---------------- GET ALL PLACES (UPGRADED with regionId support) ----------------
router.get(
  '/',
  optionalAuth,
  [
    query('category').optional().isIn(['Temples', 'Peaceful', 'Adventure', 'Heritage', 'Nature', 'Stay Places']),
    query('emotion').optional().isIn(['Spiritual', 'Peaceful', 'Adventure', 'Nature', 'Heritage']),
    query('region').optional().isString(),
    query('regionId').optional().isMongoId().withMessage('Invalid region ID'), // NEW
    query('search').optional().isString(),
    query('approved').optional().isBoolean().toBoolean(),
    query('featured').optional().isBoolean().toBoolean(),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await placeController.getPlaces(req, res);
    } catch (error) {
      console.error('Get places route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- GET PLACE BY ID ----------------
router.get(
  '/:id',
  optionalAuth,
  [param('id').isMongoId().withMessage('Invalid place id')],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await placeController.getPlaceById(req, res);
    } catch (error) {
      console.error('Get place route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- CREATE NEW PLACE ----------------
router.post(
  '/',
  partnerOrAdmin,
  [
    body('name').trim().isLength({ min: 2, max: 100 }),
    body('category').isIn(['Temples', 'Peaceful', 'Adventure', 'Heritage', 'Nature', 'Stay Places']),
    body('emotion').isIn(['Spiritual', 'Peaceful', 'Adventure', 'Nature', 'Heritage']),
    body('description').trim().isLength({ min: 10, max: 2000 }),
    body('history').optional().trim().isLength({ max: 2000 }),
    body('coverImage').notEmpty(),
    body('gallery').optional().isArray(),
    body('phone').optional().isString(),
    body('email').optional().isEmail(),
    body('timings').optional().isString(),
    body('price').optional().isFloat({ min: 0 }),
    // Accept existing payload shape: location.lat/lng are required numbers
    body('location.lat').isFloat(),
    body('location.lng').isFloat(),
    body('regionPath').notEmpty(),
    // NEW: Optional structured region references
    body('regionRef.country').optional().isMongoId(),
    body('regionRef.state').optional().isMongoId(),
    body('regionRef.district').optional().isMongoId(),
    body('regionRef.taluk').optional().isMongoId(),
    body('regionRef.town').optional().isMongoId(),
    body('regionRef.village').optional().isMongoId(),
    body('tags').optional().isArray(),
    body('amenities').optional().isArray(),
    body('bestTimeToVisit').optional().isString(),
    body('entryFee').optional().isFloat({ min: 0 }),
    body('parkingAvailable').optional().isBoolean().toBoolean(),
    body('wheelchairAccessible').optional().isBoolean().toBoolean(),
    body('petFriendly').optional().isBoolean().toBoolean()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await placeController.createPlace(req, res);
    } catch (error) {
      console.error('Create place route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- UPDATE PLACE ----------------
router.put(
  '/:id',
  protect,
  [param('id').isMongoId().withMessage('Invalid place id')],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await placeController.updatePlace(req, res);
    } catch (error) {
      console.error('Update place route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- DELETE PLACE ----------------
router.delete(
  '/:id',
  protect,
  [param('id').isMongoId().withMessage('Invalid place id')],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await placeController.deletePlace(req, res);
    } catch (error) {
      console.error('Delete place route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- ADD COMMENT ----------------
router.post(
  '/:id/comments',
  protect,
  [
    param('id').isMongoId().withMessage('Invalid place id'),
    body('text').trim().isLength({ min: 1, max: 1000 }),
    body('rating').optional().isFloat({ min: 1, max: 5 }),
    body('images').optional().isArray()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await placeController.addComment(req, res);
    } catch (error) {
      console.error('Add comment route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- CATEGORY FILTER ----------------
router.get('/category/:category', optionalAuth, async (req, res) => {
  try {
    await placeController.getPlacesByCategory(req, res);
  } catch (error) {
    console.error('Get by category route error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ---------------- EMOTION FILTER ----------------
router.get('/emotion/:emotion', optionalAuth, async (req, res) => {
  try {
    await placeController.getPlacesByEmotion(req, res);
  } catch (error) {
    console.error('Get by emotion route error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ---------------- SEARCH ----------------
router.get(
  '/search',
  optionalAuth,
  [
    query('q').notEmpty().withMessage('q is required'),
    query('category').optional().isIn(['Temples', 'Peaceful', 'Adventure', 'Heritage', 'Nature', 'Stay Places']),
    query('emotion').optional().isIn(['Spiritual', 'Peaceful', 'Adventure', 'Nature', 'Heritage'])
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await placeController.searchPlaces(req, res);
    } catch (error) {
      console.error('Search route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- APPROVE PLACE ----------------
router.put(
  '/:id/approve',
  admin,
  [
    param('id').isMongoId().withMessage('Invalid place id'),
    body('isApproved').isBoolean().toBoolean(),
    body('moderationNotes').optional().isString().isLength({ max: 1000 })
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await placeController.approvePlace(req, res);
    } catch (error) {
      console.error('Approve place route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

module.exports = router;

/*
APIs touched here:
- GET /api/places [filters: category, emotion, region, regionId (NEW), search, approved, featured, page, limit]
- GET /api/places/:id
- POST /api/places (partner/admin; respects PARTNER_AUTO_APPROVE; supports regionRef structure)
- PUT /api/places/:id (owner or admin)
- DELETE /api/places/:id (owner or admin)
- POST /api/places/:id/comments (auth required)
- GET /api/places/category/:category
- GET /api/places/emotion/:emotion
- GET /api/places/search?q=...
- PUT /api/places/:id/approve (admin; sets approvedAt, approvedBy, moderationNotes)

NEW Features:
- regionId query parameter for hierarchical region filtering
- regionRef validation for creating places with structured region references
- Proper controller separation (routes handle validation, controllers handle logic)

MongoDB integration:
- Uses upgraded Place model with regionRef fields and indexes
- Optimized wishlist enrichment via controller methods
- Supports both legacy regionPath and new regionId filtering
*/
