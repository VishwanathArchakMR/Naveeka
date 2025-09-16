// backend/controllers/authController.js
const User = require('../models/user');

/**
 * @desc Register new user
 */
exports.register = async (req, res) => {
  try {
    const { name, email, phone, password, role = 'user' } = req.body;

    // Soft pre-check (race-safe handling below too)
    const existing = await User.findByEmail(email);
    if (existing) {
      return res.status(400).json({ success: false, message: 'User already exists with this email' });
    }

    const user = await User.create({ name, email, phone, password, role });

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: { ...user.getPublicProfile(), token: user.generateAuthToken() }
    });
  } catch (err) {
    // Handle duplicate key race (unique email)
    if (err && err.code === 11000 && err.keyPattern && err.keyPattern.email) {
      return res.status(400).json({ success: false, message: 'User already exists with this email' });
    }
    console.error('Register error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Login user
 */
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findByEmail(email).select('+password');
    if (!user) return res.status(401).json({ success: false, message: 'Invalid credentials' });

    if (!user.isActive) {
      return res.status(403).json({ success: false, message: 'Account is deactivated' });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) return res.status(401).json({ success: false, message: 'Invalid credentials' });

    user.lastLogin = new Date();
    await user.save();

    res.json({
      success: true,
      message: 'Login successful',
      data: { ...user.getPublicProfile(), token: user.generateAuthToken() }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Get current user
 */
exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('-password');
    res.json({ success: true, data: user });
  } catch (err) {
    console.error('Get me error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Update profile
 */
exports.updateProfile = async (req, res) => {
  try {
    const { name, phone, preferences } = req.body;
    const user = await User.findById(req.user._id);

    if (name) user.name = name;
    if (phone) user.phone = phone;
    if (preferences) user.preferences = preferences;

    const updated = await user.save();
    res.json({ success: true, message: 'Profile updated successfully', data: updated.getPublicProfile() });
  } catch (err) {
    console.error('Update profile error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Change password
 */
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = await User.findById(req.user._id).select('+password');

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) return res.status(400).json({ success: false, message: 'Current password is incorrect' });

    user.password = newPassword;
    await user.save();

    res.json({ success: true, message: 'Password updated successfully' });
  } catch (err) {
    console.error('Change password error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
