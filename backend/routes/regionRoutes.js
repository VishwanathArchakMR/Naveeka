// backend/routes/regionRoutes.js
const express = require('express');
const { body, query, param, validationResult } = require('express-validator');
const { admin, optionalAuth } = require('../middleware/auth');
const regionController = require('../controllers/regionController');
const { REGION_TYPES } = require('../utils/constants');

const router = express.Router();

// Helper: centralized validation error handling
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

// PUBLIC ROUTES (Read Operations)

/**
 * @desc Get regions with optional filters
 * @route GET /api/regions
 * @access Public
 * @params type, parentId, search, includeStats, page, limit
 */
router.get(
  '/',
  [
    query('type').optional().isIn(REGION_TYPES).withMessage('Invalid region type'),
    query('parentId').optional().custom((value) => {
      if (value === 'null') return true; // Allow 'null' string for root regions
      return value === null || /^[0-9a-fA-F]{24}$/.test(value);
    }).withMessage('Invalid parent ID'),
    query('search').optional().isString().isLength({ min: 2, max: 100 }).withMessage('Search must be 2-100 characters'),
    query('includeStats').optional().isBoolean().toBoolean(),
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.getRegions(req, res);
    } catch (error) {
      console.error('Get regions route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * @desc Search regions by text
 * @route GET /api/regions/search
 * @access Public
 * @params q (required), type, limit
 */
router.get(
  '/search',
  [
    query('q').notEmpty().isLength({ min: 2, max: 100 }).withMessage('Search query must be 2-100 characters'),
    query('type').optional().isIn(REGION_TYPES).withMessage('Invalid region type'),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.searchRegions(req, res);
    } catch (error) {
      console.error('Search regions route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * @desc Find regions containing a geographic point
 * @route GET /api/regions/containing
 * @access Public
 * @params lng (required), lat (required), type
 */
router.get(
  '/containing',
  [
    query('lng').isFloat({ min: -180, max: 180 }).withMessage('Longitude must be between -180 and 180'),
    query('lat').isFloat({ min: -90, max: 90 }).withMessage('Latitude must be between -90 and 90'),
    query('type').optional().isIn(REGION_TYPES).withMessage('Invalid region type')
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.findContainingRegions(req, res);
    } catch (error) {
      console.error('Find containing regions route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * @desc Get region by ID
 * @route GET /api/regions/:id
 * @access Public
 * @params includeStats, includeParent
 */
router.get(
  '/:id',
  [
    param('id').isMongoId().withMessage('Invalid region ID'),
    query('includeStats').optional().isBoolean().toBoolean(),
    query('includeParent').optional().isBoolean().toBoolean()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.getRegionById(req, res);
    } catch (error) {
      console.error('Get region route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * @desc Get region breadcrumb path
 * @route GET /api/regions/:id/breadcrumb
 * @access Public
 */
router.get(
  '/:id/breadcrumb',
  [
    param('id').isMongoId().withMessage('Invalid region ID')
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.getRegionBreadcrumb(req, res);
    } catch (error) {
      console.error('Get breadcrumb route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * @desc Get direct children of a region
 * @route GET /api/regions/:id/children
 * @access Public
 * @params type, includeStats
 */
router.get(
  '/:id/children',
  [
    param('id').custom((value) => {
      if (value === 'root') return true; // Allow 'root' for top-level regions
      return /^[0-9a-fA-F]{24}$/.test(value);
    }).withMessage('Invalid region ID'),
    query('type').optional().isIn(REGION_TYPES).withMessage('Invalid region type'),
    query('includeStats').optional().isBoolean().toBoolean()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.getRegionChildren(req, res);
    } catch (error) {
      console.error('Get children route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * @desc Get all descendants of a region
 * @route GET /api/regions/:id/descendants
 * @access Public
 * @params type, includeStats
 */
router.get(
  '/:id/descendants',
  [
    param('id').isMongoId().withMessage('Invalid region ID'),
    query('type').optional().isIn(REGION_TYPES).withMessage('Invalid region type'),
    query('includeStats').optional().isBoolean().toBoolean()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.getRegionDescendants(req, res);
    } catch (error) {
      console.error('Get descendants route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * @desc Get region statistics
 * @route GET /api/regions/:id/stats
 * @access Public
 */
router.get(
  '/:id/stats',
  [
    param('id').isMongoId().withMessage('Invalid region ID')
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.getRegionStats(req, res);
    } catch (error) {
      console.error('Get stats route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ADMIN ROUTES (Write Operations)

/**
 * @desc Create a new region
 * @route POST /api/regions
 * @access Admin
 */
router.post(
  '/',
  admin,
  [
    body('name').trim().isLength({ min: 2, max: 100 }).withMessage('Name must be 2-100 characters'),
    body('type').isIn(REGION_TYPES).withMessage('Invalid region type'),
    body('parentId').optional().isMongoId().withMessage('Invalid parent ID'),
    body('code').optional().trim().isLength({ min: 1, max: 20 }).withMessage('Code must be 1-20 characters'),
    body('description').optional().trim().isLength({ max: 500 }).withMessage('Description max 500 characters'),
    body('geometry.type').optional().isIn(['Polygon', 'MultiPolygon']).withMessage('Invalid geometry type'),
    body('geometry.coordinates').optional().isArray().withMessage('Coordinates must be an array'),
    body('bbox').optional().isArray({ min: 4, max: 4 }).withMessage('Bounding box must be [minLng, minLat, maxLng, maxLat]'),
    body('bbox.*').optional().isFloat().withMessage('Bounding box values must be numbers'),
    body('metadata.population').optional().isInt({ min: 0 }).withMessage('Population must be positive integer'),
    body('metadata.area').optional().isFloat({ min: 0 }).withMessage('Area must be positive number'),
    body('metadata.established').optional().isISO8601().withMessage('Invalid date format')
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.createRegion(req, res);
    } catch (error) {
      console.error('Create region route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * @desc Update a region
 * @route PUT /api/regions/:id
 * @access Admin
 */
router.put(
  '/:id',
  admin,
  [
    param('id').isMongoId().withMessage('Invalid region ID'),
    body('name').optional().trim().isLength({ min: 2, max: 100 }).withMessage('Name must be 2-100 characters'),
    body('type').optional().isIn(REGION_TYPES).withMessage('Invalid region type'),
    body('parentId').optional().isMongoId().withMessage('Invalid parent ID'),
    body('code').optional().trim().isLength({ min: 1, max: 20 }).withMessage('Code must be 1-20 characters'),
    body('description').optional().trim().isLength({ max: 500 }).withMessage('Description max 500 characters'),
    body('geometry.type').optional().isIn(['Polygon', 'MultiPolygon']).withMessage('Invalid geometry type'),
    body('geometry.coordinates').optional().isArray().withMessage('Coordinates must be an array'),
    body('bbox').optional().isArray({ min: 4, max: 4 }).withMessage('Bounding box must be [minLng, minLat, maxLng, maxLat]'),
    body('bbox.*').optional().isFloat().withMessage('Bounding box values must be numbers'),
    body('metadata.population').optional().isInt({ min: 0 }).withMessage('Population must be positive integer'),
    body('metadata.area').optional().isFloat({ min: 0 }).withMessage('Area must be positive number'),
    body('metadata.established').optional().isISO8601().withMessage('Invalid date format'),
    body('isActive').optional().isBoolean().toBoolean()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.updateRegion(req, res);
    } catch (error) {
      console.error('Update region route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * @desc Delete a region (soft delete)
 * @route DELETE /api/regions/:id
 * @access Admin
 */
router.delete(
  '/:id',
  admin,
  [
    param('id').isMongoId().withMessage('Invalid region ID')
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await regionController.deleteRegion(req, res);
    } catch (error) {
      console.error('Delete region route error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

module.exports = router;

/*
Complete Region API:

PUBLIC ROUTES:
- GET /api/regions                    - List regions with filters
- GET /api/regions/search?q=...       - Text search regions  
- GET /api/regions/containing?lng&lat - Find regions containing point
- GET /api/regions/:id                - Get region by ID
- GET /api/regions/:id/breadcrumb     - Get hierarchical path
- GET /api/regions/:id/children       - Get direct children
- GET /api/regions/:id/descendants    - Get all descendants  
- GET /api/regions/:id/stats          - Get region statistics
- GET /api/regions/root/children      - Get root level regions (countries)

ADMIN ROUTES:
- POST /api/regions                   - Create region
- PUT /api/regions/:id                - Update region
- DELETE /api/regions/:id             - Soft delete region

Examples:
- GET /api/regions?type=state&parentId=india_id&includeStats=true
- GET /api/regions/search?q=Udupi&type=district&limit=10
- GET /api/regions/containing?lng=74.7421&lat=13.3409&type=district
- GET /api/regions/karnataka_id/children?type=district&includeStats=true
- GET /api/regions/udupi_id/breadcrumb
- GET /api/regions/karnataka_id/stats
*/
