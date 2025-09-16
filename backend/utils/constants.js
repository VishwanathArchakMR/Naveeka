// backend/utils/constants.js

// User roles used across auth, routes, and validations
const ROLES = Object.freeze({
  USER: 'user',
  PARTNER: 'partner',
  ADMIN: 'admin'
});

// App-wide emotion tags (aligns with Place.emotion enum and AI service)
const EMOTIONS = Object.freeze([
  'Spiritual',
  'Peaceful',
  'Adventure',
  'Nature',
  'Heritage'
]);

// App-wide categories (aligns with Place.category enum and filters)
const CATEGORIES = Object.freeze([
  'Temples',
  'Peaceful',
  'Adventure',
  'Heritage',
  'Nature',
  'Stay Places'
]);

// NEW: Hierarchical region types for structured region graph
const REGION_TYPES = Object.freeze([
  'country',
  'state',
  'district',
  'taluk',
  'town',
  'village'
]);

// Common pagination defaults
const PAGINATION = Object.freeze({
  DEFAULT_LIMIT: 20,
  MAX_LIMIT: 50
});

// Upload/media defaults (mirrors uploadRoutes)
const MEDIA = Object.freeze({
  BASE_FOLDER: process.env.SOULTRAIL_MEDIA_FOLDER || 'atlasTrail', // Updated for AtlasTrail
  APPEND_ENV: (process.env.SOULTRAIL_MEDIA_APPEND_ENV || 'false') === 'true'
});

// AI defaults
const AI = Object.freeze({
  PROVIDER: (process.env.AI_PROVIDER || 'mock').toLowerCase(), // 'openai' | 'huggingface' | 'mock'
  OPENAI_MODEL: process.env.OPENAI_MODEL || 'gpt-4o-mini'
});

// NEW: Social + Booking enums for upcoming features
const POST_KINDS = Object.freeze(['photo', 'video', 'reel', 'longform']); // social posts kinds [web:96]
const VISIBILITY = Object.freeze(['public', 'followers', 'private']); // who can view [web:96]
const REACTION_KINDS = Object.freeze(['like', 'save', 'share']); // supported reactions [web:96]

const EXPERIENCE_TYPES = Object.freeze([
  'stay',       // hotels, homestays, resorts
  'activity',   // tours, guides, experiences
  'darshan',    // temple tickets/puja
  'transport'   // bus/train/flight/auto (deep link first)
]); // booking inventory types [web:95]

const BOOKING_STATUS = Object.freeze([
  'pending',
  'confirmed',
  'cancelled',
  'completed'
]); // booking lifecycle states (enum-like constants) [web:95]

// Export
module.exports = {
  ROLES,
  EMOTIONS,
  CATEGORIES,
  REGION_TYPES,
  PAGINATION,
  MEDIA,
  AI,
  POST_KINDS,
  VISIBILITY,
  REACTION_KINDS,
  EXPERIENCE_TYPES,
  BOOKING_STATUS
};

/*
Usage examples:

// In middleware/auth.js:
const { ROLES } = require('../utils/constants');

// In models/place.js:
const { EMOTIONS, CATEGORIES } = require('../utils/constants');

// In models/region.js:
const { REGION_TYPES } = require('../utils/constants');

// In social models/controllers:
const { POST_KINDS, VISIBILITY, REACTION_KINDS } = require('../utils/constants');

// In booking models/controllers:
const { EXPERIENCE_TYPES, BOOKING_STATUS } = require('../utils/constants');

// In services/ai:
const { AI } = require('../utils/constants');
*/


