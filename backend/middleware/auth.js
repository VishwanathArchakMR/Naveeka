// middleware/auth.js
const jwt = require('jsonwebtoken');
const User = require('../models/user');

// Optional: centralize role names here to avoid typos
const ROLES = Object.freeze({
  USER: 'user',
  PARTNER: 'partner',
  ADMIN: 'admin'
});

/**
 * Protect routes - Requires valid JWT
 */
const protect = async (req, res, next) => {
  let token;

  // Accept token from Authorization header (Bearer <token>)
  const header = req.headers.authorization || '';
  if (header.startsWith('Bearer ')) {
    token = header.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({ success: false, message: 'Not authorized, no token provided' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Attach user (safe fields only)
    req.user = await User.findById(decoded.id).select('-password -__v');
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'User not found' });
    }
    if (req.user.isActive === false) {
      return res.status(403).json({ success: false, message: 'User account is deactivated' });
    }

    return next();
  } catch (error) {
    // TokenExpiredError, JsonWebTokenError, etc.
    return res.status(401).json({ success: false, message: 'Not authorized, token invalid or expired' });
  }
};

/**
 * Admin-only access
 */
const admin = (req, res, next) => {
  if (req.user && req.user.role === ROLES.ADMIN) {
    return next();
  }
  return res.status(403).json({ success: false, message: 'Access denied. Admin role required.' });
};

/**
 * Partner-only access
 */
const partner = (req, res, next) => {
  if (req.user && req.user.role === ROLES.PARTNER) {
    return next();
  }
  return res.status(403).json({ success: false, message: 'Access denied. Partner role required.' });
};

/**
 * Partner or Admin access
 */
const partnerOrAdmin = (req, res, next) => {
  if (req.user && (req.user.role === ROLES.PARTNER || req.user.role === ROLES.ADMIN)) {
    return next();
  }
  return res.status(403).json({ success: false, message: 'Access denied. Partner or Admin role required.' });
};

/**
 * Optional authentication - Allows requests without a token
 * If a token is present and valid, attaches req.user; otherwise sets req.user = null
 */
const optionalAuth = async (req, res, next) => {
  let token;
  const header = req.headers.authorization || '';
  if (header.startsWith('Bearer ')) {
    token = header.split(' ')[1];
  }

  if (!token) {
    req.user = null;
    return next();
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = await User.findById(decoded.id).select('-password -__v');
  } catch (error) {
    // Invalid/expired token in optional mode: proceed as anonymous
    req.user = null;
  }
  return next();
};

module.exports = {
  protect,
  admin,
  partner,
  partnerOrAdmin,
  optionalAuth,
  ROLES
};

/*
APIs and MongoDB integration notes:
- This middleware secures routes by verifying JWTs and loading the user from MongoDB.
- Use `protect` for any authenticated route; use `admin`, `partner`, or `partnerOrAdmin` for role-based access.
- `optionalAuth` lets public endpoints personalize responses when a valid token is provided (e.g., marking isWishlisted).
- Expects JWT_SECRET to be set in .env.
*/
