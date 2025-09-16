// backend/controllers/discoveryController.js
const Place = require('../models/place');
const Region = require('../models/region');

/**
 * GET /api/discovery/home?regionId=&limit=
 * Returns home sections for Explore:
 * - hero (first featured)
 * - categories/emotions chips
 * - sections: featured, latest, top_rated
 *
 * If regionId is provided, results include the region and all its descendants.
 */
exports.getHome = async (req, res) => {
  try {
    const { regionId, limit } = req.query;
    const lim = Math.min(parseInt(limit || '8', 10), 24);

    // Base filter for active and approved places
    const baseFilter = { isActive: true, isApproved: true };

    // If regionId provided, include region + descendants across regionRef levels
    if (regionId) {
      const descendants = await Region.getDescendants(regionId);
      const allIds = [regionId, ...descendants.map(d => d._id)];
      baseFilter.$or = [
        { 'regionRef.country': { $in: allIds } },
        { 'regionRef.state': { $in: allIds } },
        { 'regionRef.district': { $in: allIds } },
        { 'regionRef.taluk': { $in: allIds } },
        { 'regionRef.town': { $in: allIds } },
        { 'regionRef.village': { $in: allIds } }
      ];
    }

    // Fetch sections in parallel
    const [featured, latest, topRated] = await Promise.all([
      Place.find({ ...baseFilter, featured: true }).sort({ createdAt: -1 }).limit(lim),
      Place.find(baseFilter).sort({ createdAt: -1 }).limit(lim),
      Place.find(baseFilter).sort({ rating: -1, reviewCount: -1, createdAt: -1 }).limit(lim)
    ]);

    // Static chips for MVP (aligned with enums in Place)
    const categories = ['Temples', 'Peaceful', 'Adventure', 'Heritage', 'Nature', 'Stay Places'];
    const emotions = ['Spiritual', 'Peaceful', 'Adventure', 'Nature', 'Heritage'];

    res.json({
      success: true,
      data: {
        hero: featured.slice(0, 1),
        categories,
        emotions,
        sections: [
          { key: 'featured', title: 'Featured', items: featured },
          { key: 'latest', title: 'New & Noted', items: latest },
          { key: 'top_rated', title: 'Top Rated', items: topRated }
        ]
      }
    });
  } catch (err) {
    console.error('Discovery home error:', err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
