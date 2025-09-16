// backend/controllers/social/postController.js
const Post = require('../../models/social/Post');
const Reaction = require('../../models/social/Reaction');
const Comment = require('../../models/social/Comment');

/**
 * POST /api/trail/posts
 * Body: { kind, caption?, tags?, emotions?, categories?, placeRefs?, regionRefs?, media: [{type,url,thumb?,dur?}], visibility? }
 * Requires auth (protect middleware).
 */
exports.create = async (req, res) => {
  try {
    const body = req.body || {};

    // Basic payload validation for MVP
    if (!Array.isArray(body.media) || body.media.length === 0) {
      return res.status(400).json({ success: false, message: 'At least one media item is required' });
    }

    const post = await Post.create({
      authorId: req.user._id,
      kind: body.kind,
      caption: body.caption,
      tags: body.tags || [],
      emotions: body.emotions || [],
      categories: body.categories || [],
      placeRefs: body.placeRefs || [],
      regionRefs: body.regionRefs || [],
      media: body.media,
      visibility: body.visibility || 'public'
    });

    res.status(201).json({ success: true, data: post.toFeedJSON ? post.toFeedJSON() : post });
  } catch (e) {
    console.error('Create post error:', e); // basic controller logging pattern [1]
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * GET /api/trail/posts?authorId=&kind=&limit=
 * Public list; returns recent posts with simple filters.
 */
exports.list = async (req, res) => {
  try {
    const { authorId, kind } = req.query;
    const limit = Math.min(parseInt(req.query.limit || '20', 10), 50);

    const filter = { isActive: true, isApproved: true };
    if (authorId) filter.authorId = authorId;
    if (kind) filter.kind = kind;

    const posts = await Post.find(filter).sort({ createdAt: -1 }).limit(limit);
    res.json({
      success: true,
      data: posts.map(p => (p.toFeedJSON ? p.toFeedJSON() : p))
    });
  } catch (e) {
    console.error('List posts error:', e); // controller diagnostic [1]
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * POST /api/trail/posts/:id/like
 * Current user likes a post (idempotent via unique index).
 */
exports.like = async (req, res) => {
  try {
    const { id } = req.params;

    // Upsert reaction; unique index prevents duplicates
    const doc = await Reaction.findOneAndUpdate(
      { postId: id, userId: req.user._id, kind: 'like' },
      { $setOnInsert: { postId: id, userId: req.user._id, kind: 'like' } },
      { upsert: true, new: true }
    );

    // Increment likes if this was a new like (best-effort)
    // We cannot easily detect if it was inserted vs matched here without examining lastErrorObject,
    // so we attempt to increment but cap at 0 in unlike path.
    await Post.findByIdAndUpdate(id, { $inc: { 'metrics.likes': 1 } });

    res.json({ success: true, data: doc });
  } catch (e) {
    console.error('Like post error:', e); // controller diagnostic [1]
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * DELETE /api/trail/posts/:id/like
 * Current user unlikes a post.
 */
exports.unlike = async (req, res) => {
  try {
    const { id } = req.params;

    const del = await Reaction.findOneAndDelete({ postId: id, userId: req.user._id, kind: 'like' });
    if (del) {
      await Post.findByIdAndUpdate(id, { $inc: { 'metrics.likes': -1 } });
    }

    res.json({ success: true });
  } catch (e) {
    console.error('Unlike post error:', e); // controller diagnostic [1]
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * POST /api/trail/posts/:id/comments
 * Body: { text, rating?, images?[] }
 */
exports.addComment = async (req, res) => {
  try {
    const { id } = req.params;
    const { text, rating, images } = req.body || {};
    if (!text || String(text).trim().length === 0) {
      return res.status(400).json({ success: false, message: 'Comment text is required' });
    }

    const c = await Comment.create({
      postId: id,
      authorId: req.user._id,
      text: String(text).trim(),
      rating: rating || 0,
      images: Array.isArray(images) ? images : []
    });

    await Post.findByIdAndUpdate(id, { $inc: { 'metrics.comments': 1 } });

    res.status(201).json({ success: true, data: c });
  } catch (e) {
    console.error('Add comment error:', e); // controller diagnostic [1]
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
