// backend/routes/searchRoutes.js
const express = require('express');
const { query, validationResult } = require('express-validator');
const { optionalAuth } = require('../middleware/auth');
const searchController = require('../controllers/searchController');

const router = express.Router();

// Centralized validation error handler
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

/**
 * GET /api/search
 * q: required, 2-80
 * limit: 1-25
 * types: comma list (places,regions)
 * category, emotion, regionId optional
 */
router.get(
  '/',
  optionalAuth,
  [
    query('q').notEmpty().isLength({ min: 2, max: 80 }),
    query('limit').optional().isInt({ min: 1, max: 25 }).toInt(),
    query('types').optional().isString(),
    query('category').optional().isString(),
    query('emotion').optional().isString(),
    query('regionId').optional().isMongoId()
  ],
  async (req, res) => {
    if (handleValidationErrors(req, res)) return;
    await searchController.search(req, res);
  }
);

module.exports = router;
