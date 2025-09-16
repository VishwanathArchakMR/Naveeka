// C:\flutterapp\myapp\backend\models\Message.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

/**
 * GeoJSON Point [lng, lat] with bounds validation (RFC 7946 order).
 */
const pointSchema = new Schema(
  {
    type: { type: String, enum: ['Point'], required: true },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: true,
      validate: {
        validator: (arr) =>
          Array.isArray(arr) &&
          arr.length === 2 &&
          arr >= -180 &&
          arr <= 180 &&
          arr >= -90 &&
          arr <= 90,
        message: 'coordinates must be [lng, lat] within valid ranges'
      }
    }
  },
  { _id: false }
);

/**
 * Media/file attachment descriptor with optional signed URL and metadata.
 */
const attachmentSchema = new Schema(
  {
    key: { type: String, trim: true, index: true }, // storage key/object id
    url: { type: String, trim: true },              // signed or public URL
    name: { type: String, trim: true },
    mime: { type: String, trim: true },
    size: { type: Number, min: 0 },                 // bytes
    width: { type: Number, min: 0 },                // px (images/video)
    height: { type: Number, min: 0 },               // px
    durationSec: { type: Number, min: 0 },          // media duration if known
    thumbnail: { type: String, trim: true },        // preview image (optional)
    meta: { type: Schema.Types.Mixed }              // provider/client-specific metadata
  },
  { _id: false }
);

/**
 * Reaction with user and emoji, timestamped.
 */
const reactionSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    emoji: { type: String, required: true, trim: true },
    at: { type: Date, default: () => new Date() }
  },
  { _id: false }
);

const MessageSchema = new Schema(
  {
    // Thread and sender
    threadId: { type: Schema.Types.ObjectId, ref: 'MessageThread', required: true, index: true },
    senderId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    // Message type
    type: {
      type: String,
      enum: ['text', 'image', 'video', 'audio', 'file', 'location'],
      required: true,
      index: true
    },

    // Content
    text: { type: String, trim: true },                  // required for type=text (validated below)
    attachments: { type: [attachmentSchema], default: [] },

    // Location share (GeoJSON Point [lng,lat])
    location: { type: pointSchema },

    // Reply threading
    replyTo: { type: Schema.Types.ObjectId, ref: 'Message' }, // quoted message id (optional)

    // Reactions
    reactions: { type: [reactionSchema], default: [] },

    // State and moderation
    editedAt: { type: Date },
    deletedAt: { type: Date },

    // Extra metadata (link previews, client hints, etc.)
    meta: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true, // createdAt, updatedAt
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

// Geo index for map queries on location messages
MessageSchema.index({ location: '2dsphere' });

// Cursor/pagination and common patterns
MessageSchema.index({ threadId: 1, createdAt: -1 });
MessageSchema.index({ senderId: 1, createdAt: -1 });
MessageSchema.index({ replyTo: 1 });

// Text index for message search (free-text)
MessageSchema.index(
  { text: 'text' },
  { name: 'message_text_idx', weights: { text: 10 } }
);

// Soft-delete helper virtual
MessageSchema.virtual('isDeleted').get(function () {
  return !!this.deletedAt;
});

// Basic validator: require non-empty text for type="text" when not deleted
MessageSchema.pre('validate', function (next) {
  if (this.type === 'text' && !this.deletedAt) {
    const hasText = typeof this.text === 'string' && this.text.trim().length > 0;
    if (!hasText) {
      return next(new Error('Text message must include non-empty text'));
    }
  }
  next();
});

// Helper: minimal preview for thread lists
MessageSchema.methods.toPreview = function () {
  if (this.type === 'text') {
    return (this.text || '').slice(0, 160);
  }
  switch (this.type) {
    case 'image':
      return 'Photo';
    case 'video':
      return 'Video';
    case 'audio':
      return 'Audio';
    case 'file':
      return 'File';
    case 'location':
      return 'Location';
    default:
      return '';
  }
};

// Helper: generate RFC 7946 Feature for location messages (used by map overlays)
MessageSchema.methods.toGeoJSONFeature = function () {
  if (!this.location?.coordinates) return null;
  const [lng, lat] = this.location.coordinates;
  return {
    type: 'Feature',
    geometry: { type: 'Point', coordinates: [lng, lat] },
    properties: {
      id: this._id,
      threadId: this.threadId,
      senderId: this.senderId,
      createdAt: this.createdAt,
      geo: `geo:${lat},${lng}`
    }
  };
};

module.exports = mongoose.model('Message', MessageSchema);
