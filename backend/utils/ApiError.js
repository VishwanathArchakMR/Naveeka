// backend/utils/ApiError.js

const HTTP = {
        BAD_REQUEST: 400,
        UNAUTHORIZED: 401,
        FORBIDDEN: 403,
        NOT_FOUND: 404,
        CONFLICT: 409,
        UNPROCESSABLE_ENTITY: 422,
        TOO_MANY_REQUESTS: 429,
        INTERNAL: 500,
        SERVICE_UNAVAILABLE: 503,
        GATEWAY_TIMEOUT: 504,
      };
      
      /**
       * ApiError models an HTTP-friendly operational error with optional details,
       * a short code, and a flag to control client exposure. 
       */
      class ApiError extends Error {
        /**
         * @param {string} message human message
         * @param {object} [opts]
         * @param {number} [opts.status=500] HTTP status code
         * @param {string} [opts.code='INTERNAL_ERROR'] short, stable error code
         * @param {any} [opts.details] structured error details
         * @param {boolean} [opts.expose] whether to expose message to clients (default: status<500)
         * @param {Error} [opts.cause] underlying error
         */
        constructor(message, { status = HTTP.INTERNAL, code = 'INTERNAL_ERROR', details, expose, cause } = {}) {
          super(message);
          this.name = 'ApiError';
          this.status = status;
          this.statusCode = status;
          this.code = code;
          this.details = details;
          this.expose = typeof expose === 'boolean' ? expose : status < 500;
          this.isOperational = true;
          if (cause) this.cause = cause;
          if (Error.captureStackTrace) Error.captureStackTrace(this, ApiError);
        }
      
        /**
         * Generate an RFC 7807 Problem Details-like payload with safe exposure rules. 
         */
        toProblem({ instance, includeStack = process.env.NODE_ENV !== 'production' } = {}) {
          const body = {
            // RFC 7807 core fields
            type: undefined, // apps can set a URI here if desired
            title: this.code || 'Error',
            status: this.status,
            detail: this.expose ? this.message : undefined,
            instance,
      
            // Extensions for clients
            code: this.code,
            details: this.details,
          };
      
          if (includeStack && this.stack) {
            body.stack = this.stack;
          }
          return body;
        }
      
        /**
         * Convert any thrown error into ApiError with reasonable defaults and mappings. 
         */
        static from(err, fallbackStatus = HTTP.INTERNAL) {
          if (err instanceof ApiError) return err;
      
          // Mongoose ValidationError -> 422 with field details
          if (err && err.name === 'ValidationError') {
            const details = err.errors
              ? Object.fromEntries(
                  Object.entries(err.errors).map(([path, v]) => [
                    path,
                    { kind: v.kind, message: v.message, value: v.value },
                  ])
                )
              : { message: err.message };
            return new ApiError('Validation failed', {
              status: HTTP.UNPROCESSABLE_ENTITY,
              code: 'VALIDATION_ERROR',
              details,
              cause: err,
              expose: true,
            });
          }
      
          // Mongoose CastError -> 400 invalid input
          if (err && err.name === 'CastError') {
            return new ApiError(`Invalid value for ${err.path}`, {
              status: HTTP.BAD_REQUEST,
              code: 'CAST_ERROR',
              details: { path: err.path, value: err.value },
              cause: err,
              expose: true,
            });
          }
      
          // Mongo duplicate key E11000 -> 409 conflict
          if (err && (err.code === 11000 || /E11000/.test(String(err.message)))) {
            return new ApiError('Duplicate key', {
              status: HTTP.CONFLICT,
              code: 'DUPLICATE_KEY',
              details: err.keyValue || { message: err.message },
              cause: err,
              expose: true,
            });
          }
      
          // Generic fallback
          const status = Number(err?.status || err?.statusCode) || fallbackStatus;
          const expose = status < 500;
          return new ApiError(err?.message || 'Internal Server Error', {
            status,
            code: status >= 500 ? 'INTERNAL_ERROR' : 'REQUEST_ERROR',
            details: err && typeof err === 'object' ? { name: err.name } : undefined,
            cause: err,
            expose,
          });
        }
      
        // Helper factories
        static badRequest(msg = 'Bad Request', details) {
          return new ApiError(msg, { status: HTTP.BAD_REQUEST, code: 'BAD_REQUEST', details, expose: true });
        }
        static unauthorized(msg = 'Unauthorized', details) {
          return new ApiError(msg, { status: HTTP.UNAUTHORIZED, code: 'UNAUTHORIZED', details, expose: true });
        }
        static forbidden(msg = 'Forbidden', details) {
          return new ApiError(msg, { status: HTTP.FORBIDDEN, code: 'FORBIDDEN', details, expose: true });
        }
        static notFound(msg = 'Not Found', details) {
          return new ApiError(msg, { status: HTTP.NOT_FOUND, code: 'NOT_FOUND', details, expose: true });
        }
        static conflict(msg = 'Conflict', details) {
          return new ApiError(msg, { status: HTTP.CONFLICT, code: 'CONFLICT', details, expose: true });
        }
        static unprocessable(msg = 'Unprocessable Entity', details) {
          return new ApiError(msg, { status: HTTP.UNPROCESSABLE_ENTITY, code: 'UNPROCESSABLE_ENTITY', details, expose: true });
        }
        static tooMany(msg = 'Too Many Requests', details) {
          return new ApiError(msg, { status: HTTP.TOO_MANY_REQUESTS, code: 'TOO_MANY_REQUESTS', details, expose: true });
        }
        static internal(msg = 'Internal Server Error', details) {
          return new ApiError(msg, { status: HTTP.INTERNAL, code: 'INTERNAL_ERROR', details, expose: false });
        }
        static unavailable(msg = 'Service Unavailable', details) {
          return new ApiError(msg, { status: HTTP.SERVICE_UNAVAILABLE, code: 'SERVICE_UNAVAILABLE', details, expose: false });
        }
        static gatewayTimeout(msg = 'Gateway Timeout', details) {
          return new ApiError(msg, { status: HTTP.GATEWAY_TIMEOUT, code: 'GATEWAY_TIMEOUT', details, expose: false });
        }
      }
      
      /**
       * Express error-handling middleware that emits RFC 7807-like JSON and respects headersSent. 
       */
      function errorResponder(err, req, res, next) {
        const apiErr = ApiError.from(err);
        if (res.headersSent) return next(err);
        const body = apiErr.toProblem({ instance: req.originalUrl });
        res.status(apiErr.status || HTTP.INTERNAL).json(body);
      }
      
      /**
       * Express 404 handler to convert unmatched routes into a consistent NOT_FOUND error. 
       */
      function notFoundHandler(req, res, next) {
        next(ApiError.notFound('Route not found', { method: req.method, path: req.originalUrl }));
      }
      
      module.exports = {
        ApiError,
        errorResponder,
        notFoundHandler,
        HTTP,
      };
      