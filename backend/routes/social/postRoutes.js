// backend/routes/social/postRoutes.js
const express = require('express');
const { protect, optionalAuth } = require('../../middleware/auth');
const postController = require('../../controllers/social/postController');

const router = express.Router();

// Public list of posts with simple filters (?authorId=&kind=&limit=)
router.get('/', optionalAuth, postController.list);

// Create a new post (photo/video/reel/longform)
router.post('/', protect, postController.create);

// Like/unlike a post
router.post('/:id/like', protect, postController.like);
router.delete('/:id/like', protect, postController.unlike);

// Add a comment to a post
router.post('/:id/comments', protect, postController.addComment);

module.exports = router;
