// backend/controllers/journeyController.js
const mongoose = require('mongoose');
const Journey = require('../models/journey');
const Place = require('../models/place');

// The AI service will be added in backend/services/aiService.js
// It must export a function: generateJourneySuggestions(user, queryText, options?)
let aiService;
try {
  // Lazy-load so the app runs even before the file is created
  // eslint-disable-next-line global-require
  aiService = require('../services/aiService');
} catch (e) {
  aiService = {
    // Fallback mock to avoid runtime crashes during integration
    async generateJourneySuggestions(user, queryText) {
      return {
        filters: { emotions: [], categories: [], keywords: [] },
        // suggestions here should be resolved from DB, but mock returns empty
        suggestions: [],
        rationale: 'AI service not configured; returning empty suggestions.',
        provider: 'mock',
        latencyMs: 0
      };
    }
  };
}

/**
 * @desc POST suggest emotional journey
 * Body: { queryText: string, options?: { limit?: number, region?: string } }
 */
exports.suggestJourney = async (req, res) => {
  const t0 = Date.now();
  try {
    const { queryText, options = {} } = req.body || {};
    if (!queryText || typeof queryText !== 'string' || queryText.trim().length < 2) {
      return res.status(400).json({ success: false, message: 'queryText is required' });
    }

    // Ask AI service to interpret intent and derive filters (emotions/categories/keywords/region/price)
    const aiResult = await aiService.generateJourneySuggestions(req.user, queryText.trim(), options);
    const {
      filters = {},
      rationale = '',
      provider = 'mock'
    } = aiResult || {};

    // Build a Mongo filter from AI-derived filters; only return approved & active places
    const placeFilter = { isApproved: true, isActive: true };

    if (Array.isArray(filters.emotions) && filters.emotions.length) {
      placeFilter.emotion = { $in: filters.emotions };
    }

    if (Array.isArray(filters.categories) && filters.categories.length) {
      placeFilter.category = { $in: filters.categories };
    }

    if (filters.region && typeof filters.region === 'string') {
      placeFilter.regionPath = { $regex: filters.region, $options: 'i' };
    }

    if (Array.isArray(filters.keywords) && filters.keywords.length) {
      // Match keywords against name/description/tags
      const kw = filters.keywords.filter(k => typeof k === 'string' && k.trim().length > 0);
      if (kw.length) {
        const regexes = kw.map(k => new RegExp(k, 'i'));
        placeFilter.$or = [
          { name: { $in: regexes } },
          { description: { $in: regexes } },
          { tags: { $in: regexes } }
        ];
      }
    }

    if (typeof filters.priceMin === 'number' || typeof filters.priceMax === 'number') {
      placeFilter.price = {};
      if (typeof filters.priceMin === 'number') placeFilter.price.$gte = filters.priceMin;
      if (typeof filters.priceMax === 'number') placeFilter.price.$lte = filters.priceMax;
      // Clean up empty object
      if (!Object.keys(placeFilter.price).length) delete placeFilter.price;
    }

    const limit = Math.min(Math.max(parseInt(options.limit || 12, 10) || 12, 1), 30);

    // Query the DB for candidates
    // Simple relevance sort: featured first, then rating desc, then recent
    const candidates = await Place.find(placeFilter)
      .select('name category emotion coverImage location rating price regionPath createdAt')
      .sort({ featured: -1, rating: -1, createdAt: -1 })
      .limit(limit)
      .lean();

    // Score candidates if AI returned any notion of ranking terms (keywords/emotions/categories)
    // For now, a simple heuristic based on overlaps; real provider may return scores directly
    const emotionSet = new Set(filters.emotions || []);
    const categorySet = new Set(filters.categories || []);
    const keywordSet = new Set((filters.keywords || []).map(k => (k || '').toLowerCase()));

    const Scored = candidates.map(p => {
      let score = 0;
      if (emotionSet.has(p.emotion)) score += 0.45;
      if (categorySet.has(p.category)) score += 0.35;
      if (Array.isArray(p.tags)) {
        const tagHits = p.tags.reduce((acc, t) => acc + (keywordSet.has(String(t || '').toLowerCase()) ? 1 : 0), 0);
        score += Math.min(0.20, tagHits * 0.05);
      }
      // Nudge by rating
      score += Math.min(0.15, (p.rating || 0) * 0.03);
      return { placeId: p._id, score: Math.min(1, Number(score.toFixed(4))) };
    });

    // Build suggestions with optional snippet from description first 160 chars
    const suggestions = candidates.map(p => {
      const s = Scored.find(x => String(x.placeId) === String(p._id));
      const snippet = (p.description || '').slice(0, 160);
      return {
        placeId: p._id,
        score: s ? s.score : 0,
        snippet
      };
    });

    const latencyMs = Date.now() - t0;

    // Persist journey for history
    const journey = await Journey.recordJourney({
      userId: req.user._id,
      queryText: queryText.trim(),
      filters,
      suggestions,
      rationale,
      provider,
      latencyMs
    });

    // Populate places for immediate response (frontend convenience)
    const populated = await Journey.findById(journey._id)
      .populate('suggestedPlaces.placeId', 'name category emotion coverImage location rating price regionPath')
      .lean();

    return res.status(201).json({
      success: true,
      message: 'Journey suggestions generated',
      data: populated
    });
  } catch (err) {
    console.error('Suggest journey error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc GET journey history (paginated)
 * Query: page, limit
 */
exports.getHistory = async (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page || '1', 10), 1);
    const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 50);
    const skip = (page - 1) * limit;

    const [items, total] = await Promise.all([
      Journey.find({ userId: req.user._id })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('suggestedPlaces.placeId', 'name category emotion coverImage location rating price regionPath')
        .lean(),
      Journey.countDocuments({ userId: req.user._id })
    ]);

    return res.json({
      success: true,
      data: items,
      pagination: {
        current: page,
        total: Math.ceil(total / limit),
        hasNext: skip + items.length < total,
        hasPrev: page > 1
      }
    });
  } catch (err) {
    console.error('Get history error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc GET single journey by id (must belong to requester)
 * Param: id
 */
exports.getJourneyById = async (req, res) => {
  try {
    const { id } = req.params || {};
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid journey id' });
    }

    const journey = await Journey.findById(id)
      .populate('suggestedPlaces.placeId', 'name category emotion coverImage location rating price regionPath');

    if (!journey || String(journey.userId) !== String(req.user._id)) {
      return res.status(404).json({ success: false, message: 'Journey not found' });
    }

    return res.json({ success: true, data: journey });
  } catch (err) {
    console.error('Get journey error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};
