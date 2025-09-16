// C:\flutterapp\myapp\backend\models\MessageThread.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * Participant role map is stored in a simple object: { userIdString: 'admin'|'member'|'viewer' }.
 * This enables quick authorization checks for group threads.
 */
const rolesSchema = new Schema(
  {},
  { _id: false, strict: false } // allow dynamic keys for userId -> role
);

const MessageThreadSchema = new Schema(
  {
    // dm | group
    type: { type: String, enum: ['dm', 'group'], required: true, index: true },

    // Participants (multi-key index). For DM, must be exactly two users.
    participants: [{ type: Schema.Types.ObjectId, ref: 'User', required: true, index: true }],

    // Creator/owner (for group admin default)
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    // Group fields
    title: { type: String, trim: true, index: true },
    icon: { type: String, trim: true },
    description: { type: String, trim: true },
    roles: { type: rolesSchema, default: {} }, // { userId: 'admin'|'member'|'viewer' }

    // Idempotency for DMs: sorted "userA:userB" key unique among dm threads
    dmKey: { type: String, trim: true, index: true },

    // Last message metadata for fast list rendering
    lastMessageAt: { type: Date, index: true },
    lastMessageId: { type: Schema.Types.ObjectId, ref: 'Message' },
    lastSenderId: { type: Schema.Types.ObjectId, ref: 'User' },

    // User-level thread state (mute/archive/pin)
    mutedBy: [{ type: Schema.Types.ObjectId, ref: 'User', index: true }],
    archivedBy: [{ type: Schema.Types.ObjectId, ref: 'User', index: true }],
    pinnedBy: [{ type: Schema.Types.ObjectId, ref: 'User', index: true }],

    // Free-form metadata (e.g., keywords for search, topic refs)
    metadata: { type: Schema.Types.Mixed }, // controllers search metadata.keywords with regex

    // Flags
    isActive: { type: Boolean, default: true, index: true }
  },
  {
    timestamps: true, // createdAt, updatedAt
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

/**
 * Partial unique index to enforce 1:1 DM threads per user pair.
 * - dmKey is set to "<minUserId>:<maxUserId>" in pre-validate for type='dm'.
 * - Unique constraint applies only to documents where type='dm' and dmKey is a string.
 */
MessageThreadSchema.index(
  { dmKey: 1 },
  {
    unique: true,
    partialFilterExpression: { type: 'dm', dmKey: { $type: 'string' } },
    name: 'uniq_dm_thread_by_dmKey'
  }
); // [2][8]

/**
 * Common query patterns and sorts
 */
MessageThreadSchema.index({ participants: 1, lastMessageAt: -1 });
MessageThreadSchema.index({ type: 1, participants: 1 });
MessageThreadSchema.index({ createdBy: 1, createdAt: -1 });
MessageThreadSchema.index({ isActive: 1, lastMessageAt: -1 });

/**
 * Text index for title and metadata keywords to power search in thread lists.
 */
MessageThreadSchema.index(
  {
    title: 'text',
    'metadata.keywords': 'text'
  },
  { name: 'thread_text_idx', weights: { title: 10, 'metadata.keywords': 5 } }
); // [6][18]

/**
 * Pre-validate: enforce DM invariants and compute dmKey for idempotency.
 * - For type='dm', ensure exactly two unique participants and set a stable dmKey.
 */
MessageThreadSchema.pre('validate', function (next) {
  if (this.type === 'dm') {
    const ids = (this.participants || []).map((v) => String(v));
    const uniq = Array.from(new Set(ids));
    if (uniq.length !== 2) {
      return next(new Error('DM threads must include exactly two unique participants'));
    }
    uniq.sort(); // lexicographic sort for stable key
    this.dmKey = `${uniq}:${uniq}`;
    // For a DM thread, title/icon are optional and typically derived on the fly client-side.
  } else {
    // Groups should not carry a dmKey
    this.dmKey = undefined;
  }
  next();
});

/**
 * Virtuals for convenience
 */
MessageThreadSchema.virtual('isGroup').get(function () {
  return this.type === 'group';
});

MessageThreadSchema.virtual('participantCount').get(function () {
  return Array.isArray(this.participants) ? this.participants.length : 0;
});

module.exports = mongoose.model('MessageThread', MessageThreadSchema);
