// C:\flutterapp\myapp\backend\models\ReadReceipt.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

const ReadReceiptSchema = new Schema(
  {
    // Thread and user pair (one receipt per user per thread)
    threadId: { type: Schema.Types.ObjectId, ref: 'MessageThread', required: true, index: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    // Last read message reference and time
    lastReadMessageId: { type: Schema.Types.ObjectId, ref: 'Message', index: true },
    lastReadAt: { type: Date, default: () => new Date(), index: true }
  },
  {
    timestamps: true, // createdAt, updatedAt
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

// Ensure one receipt per user per thread (idempotent markRead semantics)
ReadReceiptSchema.index(
  { threadId: 1, userId: 1 },
  { unique: true, name: 'uniq_user_thread_read_receipt' }
); // [1]

// Fast lookups for unread computations and analytics
ReadReceiptSchema.index({ threadId: 1, lastReadMessageId: 1 });
ReadReceiptSchema.index({ userId: 1, updatedAt: -1 });

// Helper: advance to a newer message id and timestamp
ReadReceiptSchema.methods.updateTo = function ({ messageId, at = new Date() }) {
  this.lastReadMessageId = messageId || this.lastReadMessageId;
  this.lastReadAt = at;
  return this;
};

module.exports = mongoose.model('ReadReceipt', ReadReceiptSchema);
