// backend/controllers/regionController.js
const mongoose = require('mongoose');
const Region = require('../models/region');
const { REGION_TYPES, PAGINATION } = require('../utils/constants');

/**
 * Safely coerce query parameters
 */
const coerceBoolean = (v) => (typeof v === 'string' ? v === 'true' : typeof v === 'boolean' ? v : undefined);
const coerceInt = (v, def) => {
  const n = parseInt(v, 10);
  return Number.isNaN(n) ? def : n;
};

/**
 * @desc Get regions with optional filters
 * @route GET /api/regions
 * @access Public
 */
exports.getRegions = async (req, res) => {
  try {
    const {
      type,
      parentId,
      search,
      includeStats
    } = req.query;

    const page = coerceInt(req.query.page, 1);
    const limit = coerceInt(req.query.limit, PAGINATION.DEFAULT_LIMIT);
    const withStats = coerceBoolean(includeStats);

    let query = { isActive: true };
    
    // Filter by type
    if (type && REGION_TYPES.includes(type)) {
      query.type = type;
    }
    
    // Filter by parent (null for root regions)
    if (parentId === 'null' || parentId === null) {
      query.parentId = null;
    } else if (parentId && mongoose.Types.ObjectId.isValid(parentId)) {
      query.parentId = parentId;
    }
    
    // Search by text
    if (search && search.trim()) {
      query.$text = { $search: search.trim() };
    }

    const skip = (page - 1) * limit;

    // Execute query
    let regionsQuery = Region.find(query);
    
    if (search) {
      regionsQuery = regionsQuery.select({ score: { $meta: 'textScore' } })
        .sort({ score: { $meta: 'textScore' }, name: 1 });
    } else {
      regionsQuery = regionsQuery.sort({ type: 1, name: 1 });
    }

    const regions = await regionsQuery
      .skip(skip)
      .limit(limit)
      .lean();

    const total = await Region.countDocuments(query);

    // Add statistics if requested
    let results = regions;
    if (withStats && results.length > 0) {
      results = await Promise.all(
        regions.map(async (region) => {
          const stats = await Region.getStats(region._id);
          return { ...region, stats };
        })
      );
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
  } catch (error) {
    console.error('Get regions error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Get region by ID with optional population
 * @route GET /api/regions/:id
 * @access Public
 */
exports.getRegionById = async (req, res) => {
  try {
    const { id } = req.params;
    const includeStats = coerceBoolean(req.query.includeStats);
    const includeParent = coerceBoolean(req.query.includeParent);

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid region ID' });
    }

    let query = Region.findById(id);
    
    // Populate parent if requested
    if (includeParent) {
      query = query.populate('parentId', 'name type');
    }

    const region = await query.lean();

    if (!region || !region.isActive) {
      return res.status(404).json({ success: false, message: 'Region not found' });
    }

    // Add statistics if requested
    let result = region;
    if (includeStats) {
      const stats = await Region.getStats(region._id);
      result = { ...region, stats };
    }

    res.json({ success: true, data: result });
  } catch (error) {
    console.error('Get region error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Get region breadcrumb path
 * @route GET /api/regions/:id/breadcrumb
 * @access Public
 */
exports.getRegionBreadcrumb = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid region ID' });
    }

    const breadcrumb = await Region.getBreadcrumb(id);

    if (breadcrumb.length === 0) {
      return res.status(404).json({ success: false, message: 'Region not found' });
    }

    res.json({ success: true, data: breadcrumb });
  } catch (error) {
    console.error('Get breadcrumb error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Get direct children of a region
 * @route GET /api/regions/:id/children
 * @access Public
 */
exports.getRegionChildren = async (req, res) => {
  try {
    const { id } = req.params;
    const { type, includeStats } = req.query;
    const withStats = coerceBoolean(includeStats);

    let parentId = null;
    if (id !== 'root') {
      if (!mongoose.Types.ObjectId.isValid(id)) {
        return res.status(400).json({ success: false, message: 'Invalid region ID' });
      }
      parentId = id;
    }

    const childType = type && REGION_TYPES.includes(type) ? type : null;
    let children = await Region.getChildren(parentId, childType).lean();

    // Add statistics if requested
    if (withStats && children.length > 0) {
      children = await Promise.all(
        children.map(async (child) => {
          const stats = await Region.getStats(child._id);
          return { ...child, stats };
        })
      );
    }

    res.json({ success: true, data: children });
  } catch (error) {
    console.error('Get children error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Get all descendants of a region
 * @route GET /api/regions/:id/descendants
 * @access Public
 */
exports.getRegionDescendants = async (req, res) => {
  try {
    const { id } = req.params;
    const { type, includeStats } = req.query;
    const withStats = coerceBoolean(includeStats);

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid region ID' });
    }

    let descendants = await Region.getDescendants(id).lean();

    // Filter by type if specified
    if (type && REGION_TYPES.includes(type)) {
      descendants = descendants.filter(d => d.type === type);
    }

    // Add statistics if requested
    if (withStats && descendants.length > 0) {
      descendants = await Promise.all(
        descendants.map(async (descendant) => {
          const stats = await Region.getStats(descendant._id);
          return { ...descendant, stats };
        })
      );
    }

    res.json({ success: true, data: descendants });
  } catch (error) {
    console.error('Get descendants error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Search regions by text
 * @route GET /api/regions/search
 * @access Public
 */
exports.searchRegions = async (req, res) => {
  try {
    const { q, type, limit } = req.query;

    if (!q || q.trim().length < 2) {
      return res.status(400).json({ 
        success: false, 
        message: 'Search query must be at least 2 characters' 
      });
    }

    const searchLimit = coerceInt(limit, 10);
    const regionType = type && REGION_TYPES.includes(type) ? type : null;

    const results = await Region.search(q.trim(), regionType)
      .limit(searchLimit)
      .lean();

    res.json({ success: true, data: results });
  } catch (error) {
    console.error('Search regions error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Get region statistics
 * @route GET /api/regions/:id/stats
 * @access Public
 */
exports.getRegionStats = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid region ID' });
    }

    const region = await Region.findById(id);
    if (!region || !region.isActive) {
      return res.status(404).json({ success: false, message: 'Region not found' });
    }

    const stats = await Region.getStats(id);

    res.json({ success: true, data: stats });
  } catch (error) {
    console.error('Get region stats error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Find regions containing a geographic point
 * @route GET /api/regions/containing?lng=...&lat=...
 * @access Public
 */
exports.findContainingRegions = async (req, res) => {
  try {
    const { lng, lat, type } = req.query;

    const longitude = parseFloat(lng);
    const latitude = parseFloat(lat);

    if (isNaN(longitude) || isNaN(latitude)) {
      return res.status(400).json({ 
        success: false, 
        message: 'Invalid coordinates. Please provide valid lng and lat parameters.' 
      });
    }

    if (longitude < -180 || longitude > 180 || latitude < -90 || latitude > 90) {
      return res.status(400).json({ 
        success: false, 
        message: 'Coordinates out of range. lng: -180 to 180, lat: -90 to 90' 
      });
    }

    const regionType = type && REGION_TYPES.includes(type) ? type : null;
    const regions = await Region.findContaining(longitude, latitude, regionType).lean();

    res.json({ success: true, data: regions });
  } catch (error) {
    console.error('Find containing regions error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// ADMIN ROUTES (Create, Update, Delete)

/**
 * @desc Create a new region
 * @route POST /api/regions
 * @access Admin
 */
exports.createRegion = async (req, res) => {
  try {
    const regionData = { ...req.body };

    // Validate parent exists if provided
    if (regionData.parentId) {
      const parent = await Region.findById(regionData.parentId);
      if (!parent) {
        return res.status(400).json({ success: false, message: 'Parent region not found' });
      }
    }

    const region = await Region.create(regionData);
    await region.populate('parentId', 'name type');

    res.status(201).json({
      success: true,
      message: 'Region created successfully',
      data: region
    });
  } catch (error) {
    console.error('Create region error:', error);
    
    // Handle validation errors
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(err => err.message);
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: messages
      });
    }

    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Update a region
 * @route PUT /api/regions/:id
 * @access Admin
 */
exports.updateRegion = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid region ID' });
    }

    // Validate parent exists if being updated
    if (req.body.parentId) {
      const parent = await Region.findById(req.body.parentId);
      if (!parent) {
        return res.status(400).json({ success: false, message: 'Parent region not found' });
      }
    }

    const region = await Region.findByIdAndUpdate(
      id,
      { ...req.body, updatedAt: Date.now() },
      { new: true, runValidators: true }
    ).populate('parentId', 'name type');

    if (!region) {
      return res.status(404).json({ success: false, message: 'Region not found' });
    }

    res.json({
      success: true,
      message: 'Region updated successfully',
      data: region
    });
  } catch (error) {
    console.error('Update region error:', error);
    
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(err => err.message);
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: messages
      });
    }

    res.status(500).json({ success: false, message: 'Server error' });
  }
};

/**
 * @desc Delete a region (soft delete by setting isActive: false)
 * @route DELETE /api/regions/:id
 * @access Admin
 */
exports.deleteRegion = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: 'Invalid region ID' });
    }

    // Check if region has children
    const children = await Region.find({ parentId: id, isActive: true });
    if (children.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete region with active children. Delete children first.'
      });
    }

    // Soft delete
    const region = await Region.findByIdAndUpdate(
      id,
      { isActive: false, updatedAt: Date.now() },
      { new: true }
    );

    if (!region) {
      return res.status(404).json({ success: false, message: 'Region not found' });
    }

    res.json({
      success: true,
      message: 'Region deleted successfully'
    });
  } catch (error) {
    console.error('Delete region error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
