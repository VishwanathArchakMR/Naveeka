// C:\flutterapp\myapp\backend\services\activityService.js

'use strict';

const mongoose = require('mongoose');
const Activity = require('../models/Activity');

// ---------- Helpers ----------
function isObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

function coerceInt(v, def) {
  const n = parseInt(v, 10);
  return Number.isFinite(n) && n > 0 ? n : def;
}

function coerceFloat(v, def) {
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : def;
}

function toISO(d) {
  return new Date(d).toISOString();
}

function buildMatchFromFilters(filters = {}) {
  const {
    city,
    country,
    type,
    categories,
    tags,
    minPrice,
    maxPrice,
    minRating,
    openNow
  } = filters;

  const match = { isActive: true };

  if (city) match.city = city;
  if (country) match.country = country;
  if (type) match.type = type;

  if (categories) {
    const arr = Array.isArray(categories)
      ? categories
      : String(categories).split(',').map((s) => s.trim()).filter(Boolean);
    if (arr.length) match.categories = { $in: arr };
  }

  if (tags) {
    const arr = Array.isArray(tags)
      ? tags
      : String(tags).split(',').map((s) => s.trim()).filter(Boolean);
    if (arr.length) match.tags = { $all: arr };
  }

  if (minPrice != null || maxPrice != null) {
    match['price.amount'] = {};
    if (minPrice != null) match['price.amount'].$gte = coerceFloat(minPrice, 0);
    if (maxPrice != null) match['price.amount'].$lte = coerceFloat(maxPrice, Number.MAX_SAFE_INTEGER);
  }

  if (minRating != null) {
    match['reviews.averageRating'] = { $gte: coerceFloat(minRating, 0) };
  }

  if (openNow === true || openNow === 'true' || openNow === 1 || openNow === '1') {
    const nowISO = toISO(Date.now());
    match['availability.slots'] = {
      $elemMatch: {
        startISO: { $lte: nowISO },
        endISO: { $gte: nowISO }
      }
    };
  }

  return match;
}

function buildSort(sort) {
  // Supported: popularity, rating_desc, price_asc, price_desc, newest
  switch (sort) {
    case 'rating_desc':
      return { 'reviews.averageRating': -1, popularity: -1 };
    case 'price_asc':
      return { 'price.amount': 1 };
    case 'price_desc':
      return { 'price.amount': -1 };
    case 'newest':
      return { _id: -1 };
    default:
      return { popularity: -1, viewCount: -1 };
  }
}

// ---------- Core queries ----------
async function listActivities(params = {}) {
  const {
    page = 1,
    limit = 20,
    sort,
    city,
    country,
    type,
    categories,
    tags,
    minPrice,
    maxPrice,
    minRating,
    openNow
  } = params;

  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 20), 100);
  const skip = (p - 1) * l;

  const match = buildMatchFromFilters({
    city,
    country,
    type,
    categories,
    tags,
    minPrice,
    maxPrice,
    minRating,
    openNow
  });

  const [items, total] = await Promise.all([
    Activity.find(match)
      .sort(buildSort(sort))
      .skip(skip)
      .limit(l)
      .lean(),
    Activity.countDocuments(match)
  ]);

  return {
    items,
    page: p,
    limit: l,
    total,
    hasMore: skip + items.length < total
  };
}

async function getActivityByIdOrSlug(idOrSlug) {
  if (!idOrSlug) return null;
  if (isObjectId(idOrSlug)) {
    return Activity.findById(idOrSlug).lean();
  }
  return Activity.findOne({ slug: idOrSlug }).lean();
}

/**
 • Nearby search using $geoNear aggregation on a 2dsphere index.
 • Returns items sorted by distance ascending and includes "distanceMeters".
*/
async function getNearbyActivities({ lat, lng, radiusKm = 5, limit = 50, filters = {} }) {
  const radiusMeters = coerceFloat(radiusKm, 5) * 1000;
  const l = Math.min(coerceInt(limit, 50), 200);
  const match = buildMatchFromFilters(filters);

  const pipeline = [
    {
      $geoNear: {
        near: { type: 'Point', coordinates: [coerceFloat(lng, 0), coerceFloat(lat, 0)] },
        distanceField: 'distanceMeters',
        spherical: true,
        maxDistance: radiusMeters,
        query: match
      }
    },
    { $limit: l }
  ];

  const results = await Activity.aggregate(pipeline);
  return results;
}

/**
 • Viewport query (bbox) using $geoWithin and a GeoJSON Polygon built from min/max lng/lat.
*/
async function getByBBox({ minLng, minLat, maxLng, maxLat, limit = 100, filters = {} }) {
  const l = Math.min(coerceInt(limit, 100), 500);
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
  match.location = { $geoWithin: { $geometry: polygon } };

  const items = await Activity.find(match).limit(l).lean();
  return items;
}

/**
 • Lightweight suggestions by name/tags/city with prefix-friendly regex.
*/
async function suggestActivities({ q, limit = 10, city, country }) {
  const l = Math.min(coerceInt(limit, 10), 25);
  const regex = q ? new RegExp(String(q).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') : null;

  const match = { isActive: true };
  if (regex) {
    match.$or = [
      { name: regex },
      { city: regex },
      { tags: regex }
    ];
  }
  if (city) match.city = city;
  if (country) match.country = country;

  const items = await Activity.find(match)
    .select({ _id: 1, name: 1, slug: 1, city: 1, country: 1, tags: 1 })
    .limit(l)
    .lean();

  return items;
}

/**
 • FeatureCollection for maps (RFC 7946), using activity Point coordinates [lng, lat].
*/
async function getActivitiesGeoJSON(params = {}) {
  const { limit = 1000, ...filters } = params;
  const l = Math.min(coerceInt(limit, 1000), 5000);
  const match = buildMatchFromFilters(filters);

  const items = await Activity.find(match)
    .select({
      _id: 1,
      name: 1,
      slug: 1,
      city: 1,
      country: 1,
      type: 1,
      tags: 1,
      'price.amount': 1,
      'price.currency': 1,
      'reviews.averageRating': 1,
      location: 1
    })
    .limit(l)
    .lean();

  const features = items
    .filter((it) => it.location?.type === 'Point' && Array.isArray(it.location.coordinates))
    .map((it) => ({
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: it.location.coordinates
      },
      properties: {
        id: String(it._id),
        name: it.name,
        slug: it.slug,
        city: it.city,
        country: it.country,
        type: it.type,
        tags: it.tags || [],
        price: it.price,
        rating: it.reviews?.averageRating ?? null
      }
    }));

  return {
    type: 'FeatureCollection',
    features
  };
}

/**
 • Availability: filter slots within optional date window; returns normalized slots.
*/
async function getAvailability({ idOrSlug, startISO, endISO }) {
  const item = await getActivityByIdOrSlug(idOrSlug);
  if (!item) return { slots: [] };

  const slots = Array.isArray(item?.availability?.slots) ? item.availability.slots : [];
  let filtered = slots;

  if (startISO || endISO) {
    const start = startISO ? new Date(startISO).toISOString() : null;
    const end = endISO ? new Date(endISO).toISOString() : null;

    filtered = slots.filter((s) => {
      const sStart = new Date(s.startISO).toISOString();
      const sEnd = new Date(s.endISO).toISOString();
      if (start && sEnd < start) return false;
      if (end && sStart > end) return false;
      return true;
    });
  }

  return { slots: filtered };
}

/**
 • Quote: basic price calculation = unit price * guests with a hold expiry.
 • Controller can enforce validation against the specific slot capacity before booking.
*/
async function getQuote({ idOrSlug, slotStartISO, guests = 1, currency }) {
  const item = await getActivityByIdOrSlug(idOrSlug);
  if (!item) return null;

  const unit = item.price?.amount ?? 0;
  const curr = currency || item.price?.currency || 'INR';
  const qty = coerceInt(guests, 1);

  // Optional: verify provided slot exists
  let slot = null;
  if (slotStartISO && Array.isArray(item?.availability?.slots)) {
    slot = item.availability.slots.find((s) => String(s.startISO) === String(slotStartISO)) || null;
  }

  const total = unit * qty;
  const holdExpiryISO = toISO(Date.now() + 15 * 60 * 1000);

  return {
    activityId: String(item._id),
    name: item.name,
    slug: item.slug,
    slotStartISO: slot ? slot.startISO : slotStartISO || null,
    guests: qty,
    price: { currency: curr, unitAmount: unit, totalAmount: total },
    holdExpiryISO
  };
}

module.exports = {
  listActivities,
  getActivityByIdOrSlug,
  getNearbyActivities,
  getByBBox,
  suggestActivities,
  getActivitiesGeoJSON,
  getAvailability,
  getQuote
};
