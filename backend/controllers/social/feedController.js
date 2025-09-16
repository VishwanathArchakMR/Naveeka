// backend/controllers/social/feedController.js
const Post = require('../../models/social/Post');
const Follow = require('../../models/social/Follow');

/**
 * GET /api/trail/feed/home?limit=
 * - If authenticated: shows posts from accounts the user follows (most recent first).
 * - If not authenticated or no followees: shows recent public posts.
 */
exports.homeFeed = async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit || '30', 10), 50);

    const uid = req.user?._id;
    let filter = { isActive: true, isApproved: true };

    if (uid) {
      // Load followees for personalized feed
      const followees = await Follow.find({ followerId: uid }).select('followeeId'); // get ids user follows [2]
      const authorIds = followees.map(f => f.followeeId);

      if (authorIds.length) {
        filter = { ...filter, authorId: { $in: authorIds } }; // restrict to followees [2]
      }
    }

    // Fallback to global recent posts if no followees or unauthenticated
    const posts = await Post.find(filter)
      .sort({ createdAt: -1 })
      .limit(limit); // recent-first paging [2]

    res.json({
      success: true,
      data: posts.map(p => (p.toFeedJSON ? p.toFeedJSON() : p))
    });
  } catch (err) {
    console.error('Home feed error:', err); // standard controller logging for Express [1]
    res.status(500).json({ success: false, message: 'Server error' }); // consistent API error shape [1]
  }
};
