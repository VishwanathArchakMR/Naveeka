// backend/routes/journeyRoutes.js
const express = require('express');
const { body, param, query, validationResult } = require('express-validator');
const { protect } = require('../middleware/auth');
const journeyController = require('../controllers/journeyController');

const router = express.Router();

// Common validation error handler (explicit boolean)
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
 * POST /api/journeys/suggest
 * Body:
 *  - queryText: string (required)
 *  - options?: { limit?: number (1..30), region?: string }
 */
router.post(
  '/suggest',
  protect,
  [
    body('queryText')
      .isString()
      .trim()
      .isLength({ min: 2, max: 1000 })
      .withMessage('queryText must be 2..1000 characters long'),
    body('options').optional().isObject(),
    body('options.limit').optional().isInt({ min: 1, max: 30 }).toInt(),
    body('options.region').optional().isString().trim().isLength({ min: 2, max: 200 })
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await journeyController.suggestJourney(req, res);
    } catch (err) {
      console.error('Suggest route error:', err);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * GET /api/journeys/history?page=&limit=
 */
router.get(
  '/history',
  protect,
  [
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 50 }).toInt()
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await journeyController.getHistory(req, res);
    } catch (err) {
      console.error('History route error:', err);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

/**
 * GET /api/journeys/:id
 */
router.get(
  '/:id',
  protect,
  [param('id').isMongoId().withMessage('Invalid journey id')],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;
      await journeyController.getJourneyById(req, res);
    } catch (err) {
      console.error('Get journey by id route error:', err);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

module.exports = router;

/*
APIs exposed:
- POST /api/journeys/suggest   (auth required) — generates suggestions and stores a Journey
- GET  /api/journeys/history   (auth required, paginated) — lists user’s journeys
- GET  /api/journeys/:id       (auth required) — fetches a single journey owned by the user

Integration:
- Mounted in server.js at /api/journeys (already prepared in your upgraded server.js).
- Uses journeyController and protect middleware.
- Validates inputs to prevent unnecessary DB/AI calls.
*/
