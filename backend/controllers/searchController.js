// backend/controllers/searchController.js
const Place = require('../models/place');
const Region = require('../models/region');

/**
 * GET /api/search?q=&limit=&types=places,regions&category=&emotion=&regionId=
 * - q: required (min 2 chars)
 * - limit: default 10, max 25
 * - types: comma list (default: places,regions)
 * - category/emotion: optional filters (apply to places)
 * - regionId: scope places to region + descendants
 */
exports.search = async (req, res) => {
  try {
    const qRaw = (req.query.q || '').trim();
    if (qRaw.length < 2) {
      return res.status(400).json({ success: false, message: 'q must be at least 2 characters' });
    }

    const limit = Math.min(parseInt(req.query.limit || '10', 10), 25);
    const types = (req.query.types || 'places,regions')
      .split(',')
      .map(s => s.trim().toLowerCase())
      .filter(Boolean);

    const category = req.query.category;
    const emotion = req.query.emotion;
    const regionId = req.query.regionId;

    const tasks = [];

    // Build place filter
    if (types.includes('places')) {
      const placeFilter = {
        isActive: true,
        isApproved: true,
        $or: [
          { name: { $regex: qRaw, $options: 'i' } },
          { description: { $regex: qRaw, $options: 'i' } },
          { category: { $regex: qRaw, $options: 'i' } },
          { emotion: { $regex: qRaw, $options: 'i' } },
          { tags: { $in: [new RegExp(qRaw, 'i')] } }
        ]
      };

      if (category) placeFilter.category = category;
      if (emotion) placeFilter.emotion = emotion;

      if (regionId) {
        // Scope to region + descendants for places
        tasks.push((async () => {
          const descendants = await Region.getDescendants(regionId);
          const all = [regionId, ...descendants.map(d => d._id)];
          const scoped = {
            ...placeFilter,
            $or: [
              ...(placeFilter.$or || []),
              { 'regionRef.country': { $in: all } },
              { 'regionRef.state': { $in: all } },
              { 'regionRef.district': { $in: all } },
              { 'regionRef.taluk': { $in: all } },
              { 'regionRef.town': { $in: all } },
              { 'regionRef.village': { $in: all } }
            ]
          };
          const places = await Place.find(scoped).limit(limit);
          return { key: 'places', value: places };
        })());
      } else {
        tasks.push((async () => {
          const places = await Place.find(placeFilter).limit(limit);
          return { key: 'places', value: places };
        })());
      }
    }

    // Regions text search
    if (types.includes('regions')) {
      tasks.push((async () => {
        const regions = await Region.search(qRaw).limit(limit);
        return { key: 'regions', value: regions };
      })());
    }

    const results = await Promise.all(tasks);
    const out = {};
    results.forEach(({ key, value }) => { out[key] = value; });

    return res.json({ success: true, data: out });
  } catch (err) {
    console.error('Search error:', err);
    return res.status(500).json({ success: false, message: 'Server error' });
  }
};
