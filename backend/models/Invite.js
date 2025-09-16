// C:\flutterapp\myapp\backend\models\Invite.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

// Simple email syntax validator; full verification happens in service
const emailRegex =
  /^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;

const InviteSchema = new Schema(
  {
    // Target group and actors
    groupId: { type: Schema.Types.ObjectId, ref: 'TripGroup', required: true, index: true },
    inviterId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    // Recipient
    inviteeEmail: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
      match: [emailRegex, 'Invalid email address'],
      index: true
    },
    inviteeUserId: { type: Schema.Types.ObjectId, ref: 'User' }, // if user already registered

    // Access level in group
    role: {
      type: String,
      enum: ['member', 'admin', 'viewer'],
      default: 'member',
      index: true
    },

    // Security token for accepting the invite
    token: { type: String, required: true, unique: true, index: true }, // random opaque string

    // Lifecycle
    status: {
      type: String,
      enum: ['pending', 'accepted', 'revoked', 'expired'],
      default: 'pending',
      index: true
    },
    sentAt: { type: Date, default: () => new Date(), index: true },
    acceptedAt: { type: Date },
    revokedAt: { type: Date },

    // Expiration; used by TTL index to auto-remove pending invites
    // Set expiresAt only for pending invites. When accepted/revoked, set to null to retain record.
    expiresAt: { type: Date, index: true },

    // Optional message and context
    message: { type: String, trim: true },
    metadata: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true, // createdAt, updatedAt
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

/**
 * Uniqueness:
 * - Prevent multiple pending invites to the same email for the same group.
 *   Allows duplicates once a prior invite is accepted/revoked/expired.
 */
InviteSchema.index(
  { groupId: 1, inviteeEmail: 1, status: 1 },
  {
    unique: true,
    partialFilterExpression: { status: 'pending' },
    name: 'uniq_pending_invite_per_group_email'
  }
); // [15]

/**
 * TTL index:
 * - Automatically removes documents once expiresAt passes.
 * - Only documents with a Date value in expiresAt will be considered by TTL.
 * - Controllers/services should clear expiresAt when status changes to accepted/revoked.
 */
InviteSchema.index(
  { expiresAt: 1 },
  { expireAfterSeconds: 0, name: 'ttl_invite_expiry' }
); // [1][2]

/**
 * Convenience: virtual field indicating whether the invite is still actionable.
 */
InviteSchema.virtual('isActive').get(function () {
  return this.status === 'pending' && (!this.expiresAt || this.expiresAt > new Date());
});

/**
 * Pre-validate hook to normalize state transitions and TTL behavior.
 * - If status != pending, clear expiresAt to prevent TTL deletion.
 */
InviteSchema.pre('save', function (next) {
  if (this.status !== 'pending') {
    this.expiresAt = null;
  }
  next();
});

module.exports = mongoose.model('Invite', InviteSchema);
