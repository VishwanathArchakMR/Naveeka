// backend/controllers/social/userSocialController.js
const UserSocial = require('../../models/social/UserSocial');
const Follow = require('../../models/social/Follow');

/**
 * GET /api/trail/profile/me
 * Returns or initializes the caller's social profile.
 */
exports.getMe = async (req, res) => {
  try {
    let doc = await UserSocial.findOne({ userId: req.user._id });
    if (!doc) {
      // Auto-initialize minimal profile with a generated handle if missing
      const baseHandle = (req.user.name || 'traveler').toLowerCase().replace(/[^a-z0-9]+/g, '').slice(0, 12) || 'traveler';
      const handle = `${baseHandle}${String(req.user._id).slice(-4)}`;
      doc = await UserSocial.create({
        userId: req.user._id,
        handle,
        name: req.user.name || 'Traveler'
      });
    }
    res.json({ success: true, data: doc.toPublicJSON ? doc.toPublicJSON() : doc });
  } catch (e) {
    console.error('UserSocial getMe error:', e);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * PUT /api/trail/profile/me
 * Upserts the caller's social profile (handle, bio, avatar, links, preferences).
 */
exports.upsertMe = async (req, res) => {
  try {
    const payload = {};
    ['handle', 'name', 'bio', 'avatar', 'links', 'preferences', 'locationText'].forEach(k => {
      if (req.body[k] !== undefined) payload[k] = req.body[k];
    });

    if (payload.handle) {
      payload.handle = String(payload.handle).trim().toLowerCase();
    }

    const doc = await UserSocial.findOneAndUpdate(
      { userId: req.user._id },
      { $set: { ...payload, userId: req.user._id } },
      { upsert: true, new: true, runValidators: true }
    );

    res.json({ success: true, data: doc.toPublicJSON ? doc.toPublicJSON() : doc });
  } catch (e) {
    // Duplicate handle protection
    if (e && e.code === 11000) {
      return res.status(409).json({ success: false, message: 'Handle already taken' });
    }
    console.error('UserSocial upsert error:', e);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * POST /api/trail/profile/:userId/follow
 * Current user follows :userId
 */
exports.follow = async (req, res) => {
  try {
    const targetId = req.params.userId;
    if (!targetId) return res.status(400).json({ success: false, message: 'userId required' });
    if (String(targetId) === String(req.user._id)) {
      return res.status(400).json({ success: false, message: 'Cannot follow self' });
    }

    const edge = await Follow.findOneAndUpdate(
      { followerId: req.user._id, followeeId: targetId },
      { $setOnInsert: { followerId: req.user._id, followeeId: targetId } },
      { upsert: true, new: true }
    );

    // Optionally bump counters (best-effort)
    await Promise.allSettled([
      UserSocial.updateOne({ userId: targetId }, { $inc: { 'counts.followers': 1 } }),
      UserSocial.updateOne({ userId: req.user._id }, { $inc: { 'counts.following': 1 } })
    ]);

    res.json({ success: true, data: edge });
  } catch (e) {
    console.error('Follow error:', e);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * DELETE /api/trail/profile/:userId/follow
 * Current user unfollows :userId
 */
exports.unfollow = async (req, res) => {
  try {
    const targetId = req.params.userId;
    if (!targetId) return res.status(400).json({ success: false, message: 'userId required' });
    if (String(targetId) === String(req.user._id)) {
      return res.status(400).json({ success: false, message: 'Cannot unfollow self' });
    }

    const del = await Follow.findOneAndDelete({ followerId: req.user._id, followeeId: targetId });

    if (del) {
      await Promise.allSettled([
        UserSocial.updateOne({ userId: targetId }, { $inc: { 'counts.followers': -1 } }),
        UserSocial.updateOne({ userId: req.user._id }, { $inc: { 'counts.following': -1 } })
      ]);
    }

    res.json({ success: true });
  } catch (e) {
    console.error('Unfollow error:', e);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
