// backend/middleware/auth.js
const jwt = require('jsonwebtoken');
const User = require('../models/user');

// Centralized role names to avoid typos
const ROLES = Object.freeze({
  USER: 'user',
  PARTNER: 'partner',
  ADMIN: 'admin',
});

/**
 * Protect routes — requires valid JWT in Authorization: Bearer <token>
 */
async function protect(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const hasBearer = header.toLowerCase().startsWith('bearer ');
    const token = hasBearer ? header.split(' ')[1] : null;

    if (!token) {
      return res.status(401).json({ success: false, message: 'Not authorized, no token provided' });
    }

    if (!process.env.JWT_SECRET) {
      return res.status(500).json({ success: false, message: 'Server misconfiguration: JWT secret missing' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Attach user (safe fields only)
    const user = await User.findById(decoded.id).select('-password -__v');
    if (!user) {
      return res.status(401).json({ success: false, message: 'User not found' });
    }
    if (user.isActive === false) {
      return res.status(403).json({ success: false, message: 'User account is deactivated' });
    }

    req.user = user;
    return next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Not authorized, token invalid or expired' });
  }
}

/**
 * Admin-only access
 */
function admin(req, res, next) {
  if (req.user && req.user.role === ROLES.ADMIN) return next();
  return res.status(403).json({ success: false, message: 'Access denied. Admin role required.' });
}

/**
 * Partner-only access
 */
function partner(req, res, next) {
  if (req.user && req.user.role === ROLES.PARTNER) return next();
  return res.status(403).json({ success: false, message: 'Access denied. Partner role required.' });
}

/**
 * Partner or Admin access
 */
function partnerOrAdmin(req, res, next) {
  if (req.user && (req.user.role === ROLES.PARTNER || req.user.role === ROLES.ADMIN)) return next();
  return res.status(403).json({ success: false, message: 'Access denied. Partner or Admin role required.' });
}

/**
 * Optional authentication — attaches req.user if a valid token is present, else proceeds as anonymous
 */
async function optionalAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const hasBearer = header.toLowerCase().startsWith('bearer ');
    const token = hasBearer ? header.split(' ')[1] : null;

    if (!token || !process.env.JWT_SECRET) {
      req.user = null;
      return next();
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = await User.findById(decoded.id).select('-password -__v');
    } catch {
      req.user = null; // invalid/expired token in optional mode -> anonymous
    }
    return next();
  } catch {
    req.user = null;
    return next();
  }
}

// Alias to satisfy routes that import { requireAuth }
const requireAuth = protect;

module.exports = {
  // auth
  protect,
  requireAuth,
  optionalAuth,
  // roles
  admin,
  partner,
  partnerOrAdmin,
  // constants
  ROLES,
};