// backend/routes/social/userSocialRoutes.js
const express = require('express');
const { protect } = require('../../middleware/auth');
const userSocialController = require('../../controllers/social/userSocialController');

const router = express.Router();

// Get or initialize my social profile
router.get('/me', protect, userSocialController.getMe);

// Update or create my social profile
router.put('/me', protect, userSocialController.upsertMe);

// Follow/unfollow another user by their userId
router.post('/:userId/follow', protect, userSocialController.follow);
router.delete('/:userId/follow', protect, userSocialController.unfollow);

module.exports = router;
