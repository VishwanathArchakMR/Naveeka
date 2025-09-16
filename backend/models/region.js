// backend/models/region.js
const mongoose = require('mongoose');
const { REGION_TYPES } = require('../utils/constants');

// Region schema for hierarchical geographical structure
const regionSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Region name is required'],
    trim: true,
    maxlength: 100,
    index: true
  },
  type: {
    type: String,
    required: [true, 'Region type is required'],
    enum: REGION_TYPES,
    index: true
  },
  parentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Region',
    default: null,
    index: true
  },
  path: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Region'
  }],
  code: {
    type: String,
    trim: true
    // no inline index to avoid duplication; see schema.index below
  },
  geometry: {
    type: {
      type: String,
      enum: ['Polygon', 'MultiPolygon'],
      required: function () { return !!(this.geometry && this.geometry.coordinates); }
    },
    coordinates: {
      type: mongoose.Schema.Types.Mixed,
      validate: {
        validator: function (coords) {
          return !coords || (Array.isArray(coords) && coords.length > 0);
        },
        message: 'Invalid GeoJSON coordinates'
      }
    }
  },
  bbox: {
    type: [Number],
    validate: {
      validator: function (bbox) {
        return !bbox || (Array.isArray(bbox) && bbox.length === 4);
      },
      message: 'Bounding box must be [minLng, minLat, maxLng, maxLat]'
    }
  },
  description: {
    type: String,
    trim: true,
    maxlength: 500
  },
  metadata: {
    population: { type: Number, min: 0 },
    area: { type: Number, min: 0 },
    established: { type: Date }
  },
  isActive: {
    type: Boolean,
    default: true,
    index: true
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Indexes
regionSchema.index({ name: 'text', description: 'text' });
regionSchema.index({ type: 1, parentId: 1 });
regionSchema.index({ path: 1 });
regionSchema.index({ geometry: '2dsphere' });
regionSchema.index({ bbox: 1 });
regionSchema.index({ code: 1 }, { sparse: true }); // canonical, single definition

regionSchema.virtual('fullName').get(function () { return this.name; });
regionSchema.virtual('depth').get(function () { return REGION_TYPES.indexOf(this.type); });

regionSchema.pre('save', async function (next) {
  try {
    if (this.isModified('parentId') || this.isNew) {
      if (this.parentId) {
        const parent = await this.constructor.findById(this.parentId).lean();
        if (!parent) throw new Error('Parent region not found');

        const parentDepth = REGION_TYPES.indexOf(parent.type);
        const thisDepth = REGION_TYPES.indexOf(this.type);
        if (thisDepth <= parentDepth) {
          throw new Error(`Invalid hierarchy: ${this.type} cannot be child of ${parent.type}`);
        }
        this.path = [...(parent.path || []), parent._id];
      } else {
        this.path = [];
        if (this.type !== 'country') throw new Error('Only country type can have null parent');
      }
    }
    next();
  } catch (e) {
    next(e);
  }
});

regionSchema.statics.getChildren = function (parentId = null, childType = null) {
  const query = { parentId, isActive: true };
  if (childType) query.type = childType;
  return this.find(query).sort({ name: 1 });
};

regionSchema.statics.getDescendants = function (regionId) {
  return this.find({ path: regionId, isActive: true }).sort({ type: 1, name: 1 });
};

regionSchema.statics.getBreadcrumb = async function (regionId) {
  const region = await this.findById(regionId).lean();
  if (!region) return [];
  const ancestorIds = [...region.path, region._id];
  const ancestors = await this.find({ _id: { $in: ancestorIds } }).lean();
  return ancestors.sort((a, b) => REGION_TYPES.indexOf(a.type) - REGION_TYPES.indexOf(b.type));
};

regionSchema.statics.search = function (query, type = null) {
  const searchQuery = { $text: { $search: query }, isActive: true };
  if (type) searchQuery.type = type;
  return this.find(searchQuery, { score: { $meta: 'textScore' } })
    .sort({ score: { $meta: 'textScore' }, name: 1 });
};

regionSchema.statics.findContaining = function (lng, lat, type = null) {
  const query = {
    geometry: { $geoIntersects: { $geometry: { type: 'Point', coordinates: [lng, lat] } } },
    isActive: true
  };
  if (type) query.type = type;
  return this.find(query).sort({ type: -1 });
};

regionSchema.statics.getStats = async function (regionId) {
  const Place = mongoose.model('Place');
  try {
    const descendants = await this.getDescendants(regionId);
    const allRegionIds = [regionId, ...descendants.map(d => d._id)];
    const placeCount = await Place.countDocuments({
      $or: [
        { 'regionRef.country': { $in: allRegionIds } },
        { 'regionRef.state': { $in: allRegionIds } },
        { 'regionRef.district': { $in: allRegionIds } },
        { 'regionRef.taluk': { $in: allRegionIds } },
        { 'regionRef.town': { $in: allRegionIds } },
        { 'regionRef.village': { $in: allRegionIds } }
      ],
      isActive: true,
      isApproved: true
    });
    return { placeCount, childrenCount: descendants.length };
  } catch (error) {
    console.error('Error getting region stats:', error);
    return { placeCount: 0, childrenCount: 0 };
  }
};

regionSchema.methods.getFullPath = async function () {
  const breadcrumb = await this.constructor.getBreadcrumb(this._id);
  return breadcrumb.map(r => r.name).join(' > ');
};

regionSchema.methods.contains = async function (otherRegionId) {
  const other = await this.constructor.findById(otherRegionId).lean();
  if (!other) return false;
  return other.path.some(ancestorId => ancestorId.equals(this._id));
};

module.exports = mongoose.model('Region', regionSchema);
