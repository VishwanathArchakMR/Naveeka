// C:\flutterapp\myapp\backend\services\trailService.js

'use strict';

const mongoose = require('mongoose');
const Trail = require('../models/Trail');

// ---------- Helpers ----------
function isObjectId(v) {
  return mongoose.Types.ObjectId.isValid(v);
}
function toObjectId(v) {
  return new mongoose.Types.ObjectId(v);
}
function coerceInt(v, def) {
  const n = parseInt(v, 10);
  return Number.isFinite(n) && n > 0 ? n : def;
}
function coerceFloat(v, def) {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : def;
}
function sanitizeRegex(s) {
  return s ? String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') : '';
}
function toISO(d) {
  return new Date(d).toISOString();
}

// ---------- Filters & Sort ----------
function buildMatchFromFilters(filters = {}) {
  const {
    city,
    country,
    region,
    difficulty,
    tags,
    lengthMin,
    lengthMax,
    elevGainMin,
    elevGainMax,
    openNow
  } = filters;

  const match = { isActive: true };

  if (city) match.city = city;
  if (country) match.country = country;
  if (region) match.region = region;

  const diffs = Array.isArray(difficulty)
    ? difficulty
    : difficulty
      ? String(difficulty).split(',').map((s) => s.trim()).filter(Boolean)
      : [];
  if (diffs.length) match.difficulty = { $in: diffs };

  const tagArr = Array.isArray(tags)
    ? tags
    : tags
      ? String(tags).split(',').map((s) => s.trim()).filter(Boolean)
      : [];
  if (tagArr.length) match.tags = { $all: tagArr };

  if (lengthMin != null || lengthMax != null) {
    match.lengthKm = {};
    if (lengthMin != null) match.lengthKm.$gte = coerceFloat(lengthMin, 0);
    if (lengthMax != null) match.lengthKm.$lte = coerceFloat(lengthMax, Number.MAX_SAFE_INTEGER);
  }

  if (elevGainMin != null || elevGainMax != null) {
    match.elevGainM = {};
    if (elevGainMin != null) match.elevGainM.$gte = coerceFloat(elevGainMin, 0);
    if (elevGainMax != null) match.elevGainM.$lte = coerceFloat(elevGainMax, Number.MAX_SAFE_INTEGER);
  }

  if (openNow === true || openNow === 'true' || openNow === 1 || openNow === '1') {
    match['conditions.status'] = { $in: ['open', 'caution'] };
  }

  return match;
}

function buildSort(sort) {
  switch (sort) {
    case 'length_asc':
      return { lengthKm: 1, popularity: -1 };
    case 'length_desc':
      return { lengthKm: -1, popularity: -1 };
    case 'elev_gain_desc':
      return { elevGainM: -1, popularity: -1 };
    case 'rating_desc':
      return { 'reviews.averageRating': -1, popularity: -1 };
    case 'newest':
      return { _id: -1 };
    case 'popularity':
      return { popularity: -1, viewCount: -1 };
    default:
      return { popularity: -1, viewCount: -1 };
  }
}

// ---------- List/Search ----------
async function getTrails(params = {}) {
  const {
    page = 1,
    limit = 20,
    sort,
    city,
    country,
    region,
    difficulty,
    tags,
    lengthMin,
    lengthMax,
    elevGainMin,
    elevGainMax,
    openNow
  } = params;

  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 20), 100);
  const skip = (p - 1) * l;

  const match = buildMatchFromFilters({
    city,
    country,
    region,
    difficulty,
    tags,
    lengthMin,
    lengthMax,
    elevGainMin,
    elevGainMax,
    openNow
  });

  const [items, total] = await Promise.all([
    Trail.find(match).sort(buildSort(sort)).skip(skip).limit(l).lean(),
    Trail.countDocuments(match)
  ]);

  return { items, page: p, limit: l, total, hasMore: skip + items.length < total };
}

// ---------- Details ----------
async function getTrailByIdOrSlug(idOrSlug) {
  if (!idOrSlug) return null;
  if (isObjectId(idOrSlug)) return Trail.findById(idOrSlug).lean();
  return Trail.findOne({ slug: idOrSlug }).lean();
}

// ---------- Nearby (geo) ----------
/**
 * Uses $geoNear against startLocation with a 2dsphere index to sort by proximity. [1]
 */
async function getNearbyTrails({ lat, lng, radiusKm = 10, limit = 50, filters = {} }) {
  const radiusMeters = coerceFloat(radiusKm, 10) * 1000;
  const l = Math.min(coerceInt(limit, 50), 200);
  const match = buildMatchFromFilters(filters);

  const pipeline = [
    {
      $geoNear: {
        near: { type: 'Point', coordinates: [coerceFloat(lng, 0), coerceFloat(lat, 0)] },
        distanceField: 'distanceMeters',
        spherical: true,
        maxDistance: radiusMeters,
        key: 'startLocation',
        query: match
      }
    },
    { $limit: l }
  ];

  const results = await Trail.aggregate(pipeline);
  return results;
}

// ---------- BBox (viewport) ----------
/**
 * Filters startLocation within a GeoJSON Polygon built from min/max coordinates. [1]
 */
async function getByBBox({ minLng, minLat, maxLng, maxLat, limit = 500, filters = {} }) {
  const l = Math.min(coerceInt(limit, 500), 2000);
  const polygon = {
    type: 'Polygon',
    coordinates: [[
      [coerceFloat(minLng, 0), coerceFloat(minLat, 0)],
      [coerceFloat(maxLng, 0), coerceFloat(minLat, 0)],
      [coerceFloat(maxLng, 0), coerceFloat(maxLat, 0)],
      [coerceFloat(minLng, 0), coerceFloat(maxLat, 0)],
      [coerceFloat(minLng, 0), coerceFloat(minLat, 0)]
    ]]
  };

  const match = buildMatchFromFilters(filters);
  match.startLocation = { $geoWithin: { $geometry: polygon } };

  const items = await Trail.find(match).limit(l).lean();
  return items;
}

// ---------- Suggestions ----------
async function suggestTrails({ q, limit = 10, region, country }) {
  const l = Math.min(coerceInt(limit, 10), 25);
  const rx = q ? new RegExp(sanitizeRegex(q), 'i') : null;

  const match = { isActive: true };
  if (rx) match.$or = [{ name: rx }, { city: rx }, { tags: rx }];
  if (region) match.region = region;
  if (country) match.country = country;

  const items = await Trail.find(match)
    .select({ _id: 1, name: 1, slug: 1, city: 1, country: 1, region: 1, difficulty: 1, tags: 1 })
    .limit(l)
    .lean();

  return items;
}

// ---------- GeoJSON for maps ----------
/**
 * Returns FeatureCollection of trail start points for overlays. [6]
 */
async function getTrailsGeoJSON(params = {}) {
  const { limit = 1000, ...filters } = params;
  const l = Math.min(coerceInt(limit, 1000), 5000);
  const match = buildMatchFromFilters(filters);

  const items = await Trail.find(match)
    .select({
      _id: 1,
      name: 1,
      slug: 1,
      city: 1,
      country: 1,
      region: 1,
      difficulty: 1,
      lengthKm: 1,
      'reviews.averageRating': 1,
      startLocation: 1
    })
    .limit(l)
    .lean();

  const features = items
    .filter((t) => t.startLocation?.type === 'Point' && Array.isArray(t.startLocation.coordinates))
    .map((t) => ({
      type: 'Feature',
      geometry: t.startLocation,
      properties: {
        id: String(t._id),
        name: t.name,
        slug: t.slug,
        city: t.city,
        country: t.country,
        region: t.region,
        difficulty: t.difficulty,
        lengthKm: t.lengthKm,
        rating: t.reviews?.averageRating ?? null
      }
    }));

  return { type: 'FeatureCollection', features };
}

/**
 * Returns a per-trail route geometry wrapped as FeatureCollection (LineString/MultiLineString). [6]
 */
async function getTrailRoute(idOrSlug) {
  const t = await getTrailByIdOrSlug(idOrSlug);
  if (!t) return { type: 'FeatureCollection', features: [] };

  const g = t.routeGeoJSON;
  if (g?.type === 'FeatureCollection') return g;

  if (g?.type === 'LineString' || g?.type === 'MultiLineString') {
    return {
      type: 'FeatureCollection',
      features: [{ type: 'Feature', geometry: g, properties: { id: String(t._id), slug: t.slug } }]
    };
  }

  return { type: 'FeatureCollection', features: [] };
}

// ---------- Elevation / Conditions ----------
async function getElevationProfile(idOrSlug) {
  const t = await getTrailByIdOrSlug(idOrSlug);
  if (!t) return { points: [] };
  return { points: Array.isArray(t.elevationProfile) ? t.elevationProfile : [] };
}

async function getConditions(idOrSlug) {
  const t = await getTrailByIdOrSlug(idOrSlug);
  if (!t) return { status: 'unknown', lastUpdatedISO: null, notes: null };
  const c = t.conditions || {};
  return { status: c.status || 'unknown', lastUpdatedISO: c.lastUpdatedISO || null, notes: c.notes || null };
}

// ---------- Completion / Reviews ----------
async function markCompleted(idOrSlug, userId, { occurredAtISO, distanceKm, durationMin, notes }) {
  const t = await getTrailByIdOrSlug(idOrSlug);
  if (!t) return null;

  const entry = {
    userId: toObjectId(userId),
    occurredAtISO: occurredAtISO ? toISO(occurredAtISO) : toISO(Date.now()),
    distanceKm: distanceKm != null ? coerceFloat(distanceKm, null) : null,
    durationMin: durationMin != null ? coerceInt(durationMin, null) : null,
    notes: notes || null
  };

  const updated = await Trail.findByIdAndUpdate(
    t._id,
    { $push: { completions: entry }, $set: { updatedAtISO: toISO(Date.now()) } },
    { new: true }
  ).lean();

  return updated;
}

async function addReview(idOrSlug, userId, { rating, title, text, photos }) {
  const t = await getTrailByIdOrSlug(idOrSlug);
  if (!t) return null;

  const review = {
    userId: toObjectId(userId),
    rating: coerceInt(rating, 5),
    title: title || null,
    text: text || null,
    photos: Array.isArray(photos) ? photos : [],
    createdAtISO: toISO(Date.now())
  };

  const updated = await Trail.findByIdAndUpdate(
    t._id,
    { $push: { reviewsList: review }, $set: { updatedAtISO: toISO(Date.now()) } },
    { new: true }
  ).lean();

  return updated;
}

// ---------- Photos ----------
async function getPhotos(idOrSlug, { page = 1, limit = 24 } = {}) {
  const t = await getTrailByIdOrSlug(idOrSlug);
  if (!t) return { items: [], page: 1, limit: 0, total: 0, hasMore: false };

  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 24), 100);
  const all = Array.isArray(t.photos) ? t.photos : [];
  const start = (p - 1) * l;
  const items = all.slice(start, start + l);

  return { items, page: p, limit: l, total: all.length, hasMore: start + items.length < all.length };
}

// ---------- Exports ----------
/**
 * Simple GeoJSON export of the trail (FeatureCollection). [6]
 */
async function exportGeoJSON(idOrSlug) {
  return getTrailRoute(idOrSlug);
}

/**
 * Minimal GPX 1.1 export built from LineString coordinates (lng,lat -> lon,lat). [6]
 */
async function exportGPX(idOrSlug) {
  const t = await getTrailByIdOrSlug(idOrSlug);
  if (!t) return { filename: 'trail.gpx', gpx: '' };

  const g = t.routeGeoJSON;
  const coords = g?.type === 'LineString'
    ? g.coordinates
    : g?.type === 'FeatureCollection'
      ? (g.features?.[0]?.geometry?.coordinates || [])
      : [];

  const name = (t.name || 'Trail').replace(/[<&>]/g, '');
  const lines = [];
  lines.push('<?xml version="1.0" encoding="UTF-8"?>');
  lines.push('<gpx version="1.1" creator="myapp" xmlns="http://www.topografix.com/GPX/1/1">');
  lines.push(`<trk><name>${name}</name><trkseg>`);
  for (const [lon, lat] of coords) {
    lines.push(`<trkpt lat="${lat}" lon="${lon}"></trkpt>`);
  }
  lines.push('</trkseg></trk></gpx>');
  const gpx = lines.join('');

  const filename = `${name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') || 'trail'}.gpx`;
  return { filename, gpx };
}

module.exports = {
  // list/search
  getTrails,
  getTrailByIdOrSlug,
  getNearbyTrails,
  getByBBox,
  suggestTrails,
  getTrailsGeoJSON,
  // details
  getTrailRoute,
  getElevationProfile,
  getConditions,
  // actions
  markCompleted,
  addReview,
  // media
  getPhotos,
  // exports
  exportGeoJSON,
  exportGPX
};
