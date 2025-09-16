// middleware/errorHandler.js

// Optional helpers to normalize common DB errors
const normalizeError = (err) => {
  // Mongo duplicate key (e.g., unique email)
  if (err && err.code === 11000) {
    const fields = err.keyValue ? Object.keys(err.keyValue) : Object.keys(err.keyPattern || {});
    const fieldList = fields.length ? fields.join(', ') : 'field';
    return {
      statusCode: 400,
      message: `Duplicate value for ${fieldList}`
    };
  }

  // Mongoose CastError (invalid ObjectId)
  if (err && err.name === 'CastError' && err.kind === 'ObjectId') {
    return {
      statusCode: 400,
      message: 'Invalid identifier format'
    };
  }

  // Mongoose ValidationError
  if (err && err.name === 'ValidationError') {
    const messages = Object.values(err.errors || {}).map(e => e.message);
    return {
      statusCode: 400,
      message: 'Validation failed',
      errors: messages
    };
  }

  // JWT errors (optional)
  if (err && (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError')) {
    return {
      statusCode: 401,
      message: 'Not authorized, token invalid or expired'
    };
  }

  // Default: return as-is; caller will fall back to 500 if none present
  return null;
};

// Standard Express error handler signature
function errorHandler(err, req, res, next) {
  // Normalize well-known errors to consistent client responses
  const normalized = normalizeError(err);

  // Log detailed errors only in development
  if (process.env.NODE_ENV !== 'production') {
    console.error(err.stack || err);
  } else {
    console.error(err.message || err);
  }

  // Use normalized status/message if available, else fallback
  const statusCode = (normalized && normalized.statusCode) || err.statusCode || err.status || 500;
  const message = (normalized && normalized.message) || err.message || 'Internal Server Error';

  // Build response body
  const response = {
    success: false,
    message
  };

  // Include normalized validation errors if any
  if (normalized && Array.isArray(normalized.errors) && normalized.errors.length) {
    response.errors = normalized.errors;
  } else if (err && err.errors) {
    // Preserve existing behavior: include original errors only if present
    response.errors = err.errors;
  }

  // Include stack only in non-production for security
  if (process.env.NODE_ENV !== 'production') {
    response.stack = err.stack;
  }

  res.status(statusCode).json(response);
}

module.exports = errorHandler;

/*
APIs and MongoDB integration notes:
- Centralized error responses for all routes/controllers.
- Normalizes common DB/JWT errors:
  - 11000 duplicate key -> 400 with a helpful field message
  - CastError (invalid ObjectId) -> 400
  - ValidationError -> 400 with collected messages
  - JWT errors -> 401
- Keeps your response shape: { success: false, message, errors?, stack? }.
*/
