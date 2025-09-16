// C:\flutterapp\myapp\backend\models\Favorite.js

const mongoose = require('mongoose');
const { Schema } = mongoose;

const FavoriteSchema = new Schema(
  {
    // Owner of the favorite
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    // What type of entity is favorited
    // Allowed values across the app: 'place','hotel','restaurant','activity','airport','train_station','bus_stop','landmark'
    entityType: {
      type: String,
      required: true,
      trim: true,
      index: true
    },

    // The entity document id
    entityId: {
      type: Schema.Types.ObjectId,
      required: true,
      index: true
    },

    // User-defined tags for grouping and quick filters
    tags: [{ type: String, trim: true, index: true }],

    // Optional note or context from user
    note: { type: String, trim: true },

    // Soft flags
    isArchived: { type: Boolean, default: false, index: true },
    isHidden: { type: Boolean, default: false, index: true },

    // Misc metadata (e.g., source screen, campaign, etc.)
    metadata: { type: Schema.Types.Mixed }
  },
  {
    timestamps: true, // adds createdAt and updatedAt as Date fields
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
    versionKey: false
  }
);

// Enforce idempotency: a user can favorite a specific entity only once
FavoriteSchema.index(
  { userId: 1, entityType: 1, entityId: 1 },
  { unique: true, name: 'uniq_user_entity_favorite' }
);

// Useful secondary indexes for common queries
FavoriteSchema.index({ userId: 1, entityType: 1, createdAt: -1 });
FavoriteSchema.index({ userId: 1, tags: 1, createdAt: -1 });
FavoriteSchema.index({ entityType: 1, entityId: 1 }); // quick backrefs/maintenance

// Helper virtual for quick “isActive” determination (archived/hidden considered inactive)
FavoriteSchema.virtual('isActive').get(function () {
  return !this.isArchived && !this.isHidden;
});

module.exports = mongoose.model('Favorite', FavoriteSchema);
