// backend/utils/ApiResponse.js

/**
 * Success envelope for single payloads.
 * Example:
 *   res.json(ApiResponse.success(data))
 */
function success(data, meta) {
        return {
          success: true,
          data,
          meta: meta ?? null,
        };
      }
      
      /**
       * Paginated envelope for cursor-based or offset-based results.
       * Example (cursor):
       *   res.json(ApiResponse.page(items, { nextCursor, count: items.length }))
       * Example (offset):
       *   res.json(ApiResponse.page(items, { total, page, pageSize }))
       */
      function page(items, meta = {}) {
        return {
          success: true,
          data: Array.isArray(items) ? items : [],
          meta: {
            count: Array.isArray(items) ? items.length : 0,
            ...meta,
          },
        };
      }
      
      /**
       * Minimal OK helper with message and optional extras.
       * Example:
       *   res.json(ApiResponse.ok('Updated', { id }))
       */
      function ok(message = 'OK', extra = null) {
        return {
          success: true,
          message,
          ...(extra && typeof extra === 'object' ? extra : {}),
        };
      }
      
      /**
       * Normalize boolean acknowledgment responses.
       * Example:
       *   res.json(ApiResponse.ack(true)) // { success: true }
       *   res.json(ApiResponse.ack(false, 'Not modified')) // { success: false, message: 'Not modified' }
       */
      function ack(okBool, message) {
        return {
          success: Boolean(okBool),
          ...(message ? { message } : {}),
        };
      }
      
      module.exports = {
        success,
        page,
        ok,
        ack,
      };
      