// backend/models/journey.js
const mongoose = require('mongoose');

/**
 * Journey schema captures an AI-assisted suggestion session:
 * - Who asked (userId)
 * - What they asked (queryText)
 * - How we interpreted it (emotions/categories/keywords/region filters)
 * - What we suggested (suggestedPlaces with scores and snippets)
 * - Why we suggested (rationale text)
 */

const filterSchema = new mongoose.Schema(
  {
    // Core filters derived from AI intent understanding
    emotions: [{
      type: String,
      enum: ['Spiritual', 'Peaceful', 'Adventure', 'Nature', 'Heritage'],
      trim: true
    }],
    categories: [{
      type: String,
      enum: ['Temples', 'Peaceful', 'Adventure', 'Heritage', 'Nature', 'Stay Places'],
      trim: true
    }],
    keywords: [{
      type: String,
      trim: true,
      maxlength: 50
    }],
    // Optional region constraint (free-form path you already use, e.g., "India/Karnataka/Udupi")
    region: {
      type: String,
      trim: true,
      maxlength: 200
    },
    // Optional price band guidance
    priceMin: { type: Number, min: 0, default: 0 },
    priceMax: { type: Number, min: 0 }
  },
  { _id: false }
);

const suggestedPlaceSchema = new mongoose.Schema(
  {
    placeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Place',
      required: true
    },
    // Confidence score (0–1) based on how well it fits the emotional intent
    score: {
      type: Number,
      min: 0,
      max: 1,
      default: 0
    },
    // Optional short snippet shown in UI (e.g., why it matches)
    snippet: {
      type: String,
      trim: true,
      maxlength: 300
    }
  },
  { _id: false }
);

const journeySchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true
    },
    // Free-form query or emotional prompt from the user
    queryText: {
      type: String,
      required: true,
      trim: true,
      maxlength: 1000
    },
    // Structured filters derived from AI interpretation
    filters: {
      type: filterSchema,
      default: {}
    },
    // Suggested places curated from your Place collection (no fabricated data)
    suggestedPlaces: {
      type: [suggestedPlaceSchema],
      default: []
    },
    // Optional narrative/rationale to present beside suggestions
    rationale: {
      type: String,
      trim: true,
      maxlength: 2000
    },
    // For observability/debugging of provider behavior
    provider: {
      type: String,
      enum: ['openai', 'huggingface', 'mock'],
      default: 'mock',
      index: true
    },
    // Latency in ms (optional)
    latencyMs: {
      type: Number,
      min: 0
    }
  },
  {
    timestamps: true
  }
);

// Indexes to support history queries and quick lookups
journeySchema.index({ userId: 1, createdAt: -1 });
journeySchema.index({ 'filters.emotions': 1 });
journeySchema.index({ 'filters.categories': 1 });
journeySchema.index({ 'filters.region': 1 });

// Static: get user journey history (paginated)
journeySchema.statics.getUserHistory = function (userId, { page = 1, limit = 20 } = {}) {
  const p = parseInt(page, 10) || 1;
  const l = parseInt(limit, 10) || 20;
  const skip = (p - 1) * l;
  return this.find({ userId })
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(l)
    .select('-__v');
};

// Static: create a journey record from AI output and selected places
journeySchema.statics.recordJourney = function ({
  userId,
  queryText,
  filters,
  suggestions,
  rationale,
  provider = 'mock',
  latencyMs
}) {
  // suggestions: array of { placeId, score, snippet }
  return this.create({
    userId,
    queryText,
    filters,
    suggestedPlaces: suggestions || [],
    rationale,
    provider,
    latencyMs
  });
};

module.exports = mongoose.model('Journey', journeySchema);

/*
APIs and MongoDB integration notes:
- This model is used by the AI journeys controller to persist each suggestion session.
- References:
  - userId -> User
  - suggestedPlaces[].placeId -> Place
- Typical flow:
  1) POST /api/journeys/suggest -> aiService transforms queryText into filters and queries Place.
  2) Controller saves a Journey via Journey.recordJourney().
  3) GET /api/journeys/history -> fetch with Journey.getUserHistory(userId, { page, limit }).

Expected environment for full AI flow (wired in later files):
- AI_PROVIDER=openai|huggingface|mock
- OPENAI_API_KEY / HUGGINGFACE_API_KEY (if applicable)
*/
