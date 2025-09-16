// backend/controllers/booking/experienceController.js
const Experience = require('../../models/booking/Experience');

/**
 * GET /api/journey/experiences?type=&regionId=&placeId=&limit=
 * - type: stay|activity|darshan|transport (optional)
 * - regionId: filters experiences linked to that region (optional)
 * - placeId: filters experiences linked to a place (optional)
 * - limit: default 20, max 50
 */
exports.list = async (req, res) => {
  try {
    const { type, regionId, placeId } = req.query;
    const limit = Math.min(parseInt(req.query.limit || '20', 10), 50); // guard limit for pagination [1]

    const filter = { isActive: true };
    if (type) filter.type = type;
    if (placeId) filter.placeId = placeId;
    if (regionId) filter.regionRefs = regionId;

    const items = await Experience.find(filter)
      .sort({ createdAt: -1 }) // recent first for discovery [2]
      .limit(limit);

    res.json({ success: true, data: items });
  } catch (err) {
    console.error('Experience list error:', err); // controller diagnostic pattern [1]
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
