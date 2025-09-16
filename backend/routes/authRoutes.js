// backend/routes/authRoutes.js
const express = require('express');
const { body, validationResult } = require('express-validator');
const User = require('../models/user');
const { protect } = require('../middleware/auth');

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

// ---------------- REGISTER ----------------
router.post(
  '/register',
  [
    body('name')
      .trim()
      .isLength({ min: 2, max: 50 })
      .withMessage('Name must be between 2 and 50 characters'),
    body('email')
      .isEmail()
      .normalizeEmail()
      .withMessage('Please enter a valid email'),
    body('phone')
      .matches(/^[0-9]{10}$/)
      .withMessage('Please enter a valid 10-digit phone number'),
    body('password')
      .isLength({ min: 6 })
      .withMessage('Password must be at least 6 characters long'),
    body('role')
      .optional()
      .isIn(['user', 'partner', 'admin'])
      .withMessage('Invalid role'),
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const { name, email, phone, password, role = 'user' } = req.body;

      // Check if user exists (race-safe handling below as well)
      const userExists = await User.findByEmail(email);
      if (userExists) {
        return res
          .status(400)
          .json({ success: false, message: 'User already exists with this email' });
      }

      // Create user
      const user = await User.create({ name, email, phone, password, role });

      // Return created user info + token
      res.status(201).json({
        success: true,
        message: 'User registered successfully',
        data: { ...user.getPublicProfile(), token: user.generateAuthToken() },
      });
    } catch (error) {
      // Handle duplicate email race condition from unique index
      if (error && error.code === 11000 && error.keyPattern && error.keyPattern.email) {
        return res
          .status(400)
          .json({ success: false, message: 'User already exists with this email' });
      }
      console.error('Register error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- LOGIN ----------------
router.post(
  '/login',
  [
    body('email')
      .isEmail()
      .normalizeEmail()
      .withMessage('Please enter a valid email'),
    body('password').notEmpty().withMessage('Password is required'),
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const { email, password } = req.body;

      const user = await User.findByEmail(email).select('+password');
      if (!user) {
        return res.status(401).json({ success: false, message: 'Invalid credentials' });
      }

      if (!user.isActive) {
        return res
          .status(403)
          .json({ success: false, message: 'Account is deactivated' });
      }

      const isMatch = await user.comparePassword(password);
      if (!isMatch) {
        return res.status(401).json({ success: false, message: 'Invalid credentials' });
      }

      // Update last login
      user.lastLogin = new Date();
      await user.save();

      res.json({
        success: true,
        message: 'Login successful',
        data: { ...user.getPublicProfile(), token: user.generateAuthToken() },
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- GET CURRENT USER ----------------
router.get('/me', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('-password');
    res.json({ success: true, data: user });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ---------------- UPDATE PROFILE ----------------
router.put(
  '/profile',
  protect,
  [
    body('name')
      .optional()
      .trim()
      .isLength({ min: 2, max: 50 })
      .withMessage('Name must be between 2 and 50 characters'),
    body('phone')
      .optional()
      .matches(/^[0-9]{10}$/)
      .withMessage('Please enter a valid 10-digit phone number'),
    body('preferences')
      .optional()
      .isArray()
      .withMessage('Preferences must be an array'),
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const { name, phone, preferences } = req.body;
      const user = await User.findById(req.user._id);

      if (name) user.name = name;
      if (phone) user.phone = phone;
      if (preferences) user.preferences = preferences;

      const updatedUser = await user.save();

      res.json({
        success: true,
        message: 'Profile updated successfully',
        data: updatedUser.getPublicProfile(),
      });
    } catch (error) {
      console.error('Update profile error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ---------------- CHANGE PASSWORD ----------------
router.put(
  '/password',
  protect,
  [
    body('currentPassword')
      .notEmpty()
      .withMessage('Current password is required'),
    body('newPassword')
      .isLength({ min: 6 })
      .withMessage('New password must be at least 6 characters long'),
  ],
  async (req, res) => {
    try {
      if (handleValidationErrors(req, res)) return;

      const { currentPassword, newPassword } = req.body;
      const user = await User.findById(req.user._id).select('+password');

      // Compare current password
      const isMatch = await user.comparePassword(currentPassword);
      if (!isMatch) {
        return res
          .status(400)
          .json({ success: false, message: 'Current password is incorrect' });
      }

      // Update password (pre-save hook will hash it)
      user.password = newPassword;
      await user.save();

      res.json({ success: true, message: 'Password updated successfully' });
    } catch (error) {
      console.error('Change password error:', error);
      res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

module.exports = router;

/*
APIs touched here:
- POST /api/auth/register
- POST /api/auth/login
- GET  /api/auth/me
- PUT  /api/auth/profile
- PUT  /api/auth/password

MongoDB integration:
- Uses User model (unique email constraint, password hashing via pre-save).
- Duplicate email is handled (E11000) with a clean 400 response on register.
- JWT token creation via user.generateAuthToken() (requires JWT_SECRET in .env).
*/
