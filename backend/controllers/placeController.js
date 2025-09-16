// backend/controllers/placeController.js
const mongoose = require('mongoose');
const Place = require('../models/place');
const Wishlist = require('../models/wishlist');

// Will be available after we create models/region.js in next step
let Region;
try {
  Region = require('../models/region');
} catch (e) {
  // Region model not yet created, regionId filtering will be skipped gracefully
  Region = null;
}

/**
 * Safely coerce booleans/ints from query strings
 */
const coerceBoolean = (v) => (typeof v === 'string' ? v === 'true' : typeof v === 'boolean' ? v : undefined);
const coerceInt = (v, def) => {
  const n = parseInt(v, 10);
  return Number.isNaN(n) ? def : n;
};

/**
 * Resolve regionId to descendant region IDs for hierarchical filtering
 */
async function getRegionDescendants(regionId) {
  if (!Region || !mongoose.Types.ObjectId.isValid(regionId)) {
    return null;
  }

  try {
    // Get the region and all its descendants via the path field
    const region = await Region.findById(regionId).lean();
    if (!region) return null;

    // Find all regions that have this regionId in their path (descendants)
    const descendants = await Region.find({ 
      path: regionId 
    }).select('_id').lean();

    // Return set including the region itself + all descendants
    const regionIds = [regionId, ...descendants.map(d => d._id)];
    return regionIds.map(id => new mongoose.Types.ObjectId(id));
  } catch (error) {
    console.error('Error resolving region descendants:', error);
    return null;
  }
}

/**
 * @desc Get all places with filters (UPGRADED with regionId support)
 */
exports.getPlaces = async (req, res) => {
  try {
    const category = req.query.category;
    const emotion = req.query.emotion;
    const region = req.query.region;        // Legacy regionPath regex
    const regionId = req.query.regionId;    // NEW: Structured region filtering
    const search = req.query.search;
    const approved = coerceBoolean(req.query.approved);
    const featured = coerceBoolean(req.query.featured);
    const page = coerceInt(req.query.page, 1);
    const limit = coerceInt(req.query.limit, 20);

    const filter = { isActive: true };

    if (category) filter.category = category;
    if (emotion) filter.emotion = emotion;
    if (typeof approved === 'boolean') filter.isApproved = approved;
    if (typeof featured === 'boolean') filter.featured = featured;

    // Legacy region filtering (keep for backward compatibility)
    if (region && typeof region === 'string') {
      filter.regionPath = { $regex: region, $options: 'i' };
    }

    // NEW: Structured region filtering
    if (regionId && Region) {
      const regionDescendants = await getRegionDescendants(regionId);
      if (regionDescendants && regionDescendants.length > 0) {
        // Match places in this region or any of its sub-regions
        filter.$or = [
          { 'regionRef.country': { $in: regionDescendants } },
          { 'regionRef.state': { $in: regionDescendants } },
          { 'regionRef.district': { $in: regionDescendants } },
          { 'regionRef.taluk': { $in: regionDescendants } },
          { 'regionRef.town': { $in: regionDescendants } },
          { 'regionRef.village': { $in: regionDescendants } }
        ];
      }
    }

    if (search) {
      const searchConditions = [
        { name: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { category: { $regex: search, $options: 'i' } },
        { emotion: { $regex: search, $options: 'i' } }
      ];

      // If we already have $or from regionId, combine with search
      if (filter.$or) {
        filter.$and = [
          { $or: filter.$or }, // regionId conditions
          { $or: searchConditions } // search conditions
        ];
        delete filter.$or;
      } else {
        filter.$or = searchConditions;
      }
    }

    const skip = (page - 1) * limit;

    const places = await Place.find(filter)
      .populate('createdBy', 'name')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await Place.countDocuments(filter);

    // Enrich with isWishlisted without N+1 queries
    let results = places.map(p => p.toObject());

    if (req.user && results.length > 0) {
      const ids = results.map(r => r._id);
      const userWishlist = await Wishlist.find({
        userId: req.user._id,
        placeId: { $in: ids }
      }).select('placeId');

      const wished = new Set(userWishlist.map(w => w.placeId.toString()));
      results = results.map(r => ({
        ...r,
        isWishlisted: wished.has(r._id.toString())
      }));
    }

    res.json({
      success: true,
      data: results,
      pagination: {
        current: page,
        total: Math.ceil(total / limit),
        hasNext: skip + results.length < total,
        hasPrev: page > 1
      }
    });
  } catch (err) {
    console.error('Get places error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Get place by ID
 */
exports.getPlaceById = async (req, res) => {
  try {
    let place = await Place.findById(req.params.id)
      .populate('createdBy', 'name')
      .populate('comments.userId', 'name profileImage');

    if (!place || !place.isActive) return res.status(404).json({ success: false, message: 'Place not found' });

    place = place.toObject();

    if (req.user) {
      const isInWishlist = await Wishlist.isInWishlist(req.user._id, place._id);
      place.isWishlisted = !!isInWishlist;
    }

    res.json({ success: true, data: place });
  } catch (err) {
    console.error('Get place error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Create a new place
 */
exports.createPlace = async (req, res) => {
  try {
    const partnerAutoApprove = (process.env.PARTNER_AUTO_APPROVE || 'false') === 'true';
    const isApproved =
      req.user.role === 'admin' ||
      (req.user.role === 'partner' && partnerAutoApprove);

    const place = await Place.create({
      ...req.body,
      createdBy: req.user._id,
      isApproved
    });

    await place.populate('createdBy', 'name');

    res.status(201).json({ success: true, message: 'Place created successfully', data: place });
  } catch (err) {
    console.error('Create place error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Update place
 */
exports.updatePlace = async (req, res) => {
  try {
    const place = await Place.findById(req.params.id);
    if (!place) return res.status(404).json({ success: false, message: 'Place not found' });

    if (place.createdBy.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    const updated = await Place.findByIdAndUpdate(
      req.params.id,
      { ...req.body, updatedAt: Date.now() },
      { new: true, runValidators: true }
    ).populate('createdBy', 'name');

    res.json({ success: true, message: 'Place updated', data: updated });
  } catch (err) {
    console.error('Update place error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Delete a place
 */
exports.deletePlace = async (req, res) => {
  try {
    const place = await Place.findById(req.params.id);
    if (!place) return res.status(404).json({ success: false, message: 'Place not found' });

    if (place.createdBy.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    await Place.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Place deleted' });
  } catch (err) {
    console.error('Delete place error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Add comment to place
 */
exports.addComment = async (req, res) => {
  try {
    const place = await Place.findById(req.params.id);
    if (!place) return res.status(404).json({ success: false, message: 'Place not found' });

    const commentData = {
      userId: req.user._id,
      userName: req.user.name,
      text: req.body.text,
      rating: req.body.rating || 0,
      images: req.body.images || []
    };

    const updated = await place.addComment(commentData);
    await updated.populate('comments.userId', 'name profileImage');

    res.json({ success: true, message: 'Comment added', data: updated });
  } catch (err) {
    console.error('Add comment error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Category filter
 */
exports.getPlacesByCategory = async (req, res) => {
  try {
    const places = await Place.findByCategory(req.params.category);
    let results = places.map(p => p.toObject());

    if (req.user && results.length > 0) {
      const ids = results.map(r => r._id);
      const userWishlist = await Wishlist.find({
        userId: req.user._id,
        placeId: { $in: ids }
      }).select('placeId');
      const wished = new Set(userWishlist.map(w => w.placeId.toString()));
      results = results.map(r => ({ ...r, isWishlisted: wished.has(r._id.toString()) }));
    }

    res.json({ success: true, data: results });
  } catch (err) {
    console.error('Category error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Emotion filter
 */
exports.getPlacesByEmotion = async (req, res) => {
  try {
    const places = await Place.findByEmotion(req.params.emotion);
    let results = places.map(p => p.toObject());

    if (req.user && results.length > 0) {
      const ids = results.map(r => r._id);
      const userWishlist = await Wishlist.find({
        userId: req.user._id,
        placeId: { $in: ids }
      }).select('placeId');
      const wished = new Set(userWishlist.map(w => w.placeId.toString()));
      results = results.map(r => ({ ...r, isWishlisted: wished.has(r._id.toString()) }));
    }

    res.json({ success: true, data: results });
  } catch (err) {
    console.error('Emotion error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Search
 */
exports.searchPlaces = async (req, res) => {
  try {
    const { q } = req.query;
    const places = await Place.search(q);
    let results = places.map(p => p.toObject());

    if (req.user && results.length > 0) {
      const ids = results.map(r => r._id);
      const userWishlist = await Wishlist.find({
        userId: req.user._id,
        placeId: { $in: ids }
      }).select('placeId');
      const wished = new Set(userWishlist.map(w => w.placeId.toString()));
      results = results.map(r => ({ ...r, isWishlisted: wished.has(r._id.toString()) }));
    }

    res.json({ success: true, data: results });
  } catch (err) {
    console.error('Search error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Approve/reject place (with audit fields)
 */
exports.approvePlace = async (req, res) => {
  try {
    const update = {
      isApproved: req.body.isApproved,
      moderationNotes: req.body.moderationNotes || undefined,
      approvedAt: req.body.isApproved ? new Date() : undefined,
      approvedBy: req.body.isApproved ? req.user._id : undefined
    };

    Object.keys(update).forEach(k => update[k] === undefined && delete update[k]);

    const place = await Place.findByIdAndUpdate(
      req.params.id,
      update,
      { new: true }
    ).populate('createdBy', 'name');

    if (!place) return res.status(404).json({ success: false, message: 'Place not found' });

    res.json({ success: true, message: 'Approval status updated', data: place });
  } catch (err) {
    console.error('Approve error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
