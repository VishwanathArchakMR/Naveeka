// backend/utils/asyncHandler.js

/**
 * Wrap an async/sync Express handler and funnel errors to next().
 * Usage:
 *   const asyncHandler = require('./utils/asyncHandler');
 *   router.get('/items', asyncHandler(async (req, res) => {
 *     const rows = await repo.list();
 *     res.json({ success: true, data: rows });
 *   }));
 */
function asyncHandler(fn) {
        return function wrapped(req, res, next) {
          // Support both async and sync handlers
          Promise.resolve(fn.call(this, req, res, next)).catch(next);
        };
      }
      
      module.exports = asyncHandler;
      