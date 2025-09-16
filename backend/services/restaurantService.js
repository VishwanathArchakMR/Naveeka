// C:\flutterapp\myapp\backend\services\restaurantService.js

'use strict';

const mongoose = require('mongoose');
const Restaurant = require('../models/Restaurant');

// ------------- Helpers -------------
function isObjectId(v) {
  return mongoose.Types.ObjectId.isValid(v);
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

// ------------- Filters & Sort -------------
function buildMatchFromFilters(filters = {}) {
  const {
    city,
    country,
    cuisines,
    dietary,
    features,
    minPrice,
    maxPrice,
    openNow,
    minRating
  } = filters;

  const match = { isActive: true };

  if (city) match.city = city;
  if (country) match.country = country;

  const splitOrArr = (x) =>
    Array.isArray(x) ? x : (x ? String(x).split(',').map((s) => s.trim()).filter(Boolean) : []);

  const cuisinesArr = splitOrArr(cuisines);
  if (cuisinesArr.length) match.cuisines = { $in: cuisinesArr };

  const dietaryArr = splitOrArr(dietary);
  if (dietaryArr.length) match.dietary = { $all: dietaryArr };

  const featuresArr = splitOrArr(features);
  if (featuresArr.length) match.features = { $all: featuresArr };

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
      $elemMatch: { startISO: { $lte: nowISO }, endISO: { $gte: nowISO } }
    };
  }

  return match;
}

function buildSort(sort) {
  switch (sort) {
    case 'rating_desc':
      return { 'reviews.averageRating': -1, popularity: -1 };
    case 'price_asc':
      return { 'price.amount': 1, popularity: -1 };
    case 'price_desc':
      return { 'price.amount': -1, popularity: -1 };
    case 'newest':
      return { _id: -1 };
    case 'popularity':
      return { popularity: -1, viewCount: -1 };
    default:
      return { popularity: -1, viewCount: -1 };
  }
}

// ------------- List/Search -------------
async function listRestaurants(params = {}) {
  const {
    page = 1,
    limit = 20,
    sort,
    city,
    country,
    cuisines,
    dietary,
    features,
    minPrice,
    maxPrice,
    openNow,
    minRating
  } = params;

  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 20), 100);
  const skip = (p - 1) * l;

  const match = buildMatchFromFilters({
    city,
    country,
    cuisines,
    dietary,
    features,
    minPrice,
    maxPrice,
    openNow,
    minRating
  });

  const [items, total] = await Promise.all([
    Restaurant.find(match).sort(buildSort(sort)).skip(skip).limit(l).lean(),
    Restaurant.countDocuments(match)
  ]);

  return {
    items,
    page: p,
    limit: l,
    total,
    hasMore: skip + items.length < total
  };
}

// ------------- Details -------------
async function getRestaurantByIdOrSlug(idOrSlug) {
  if (!idOrSlug) return null;
  if (isObjectId(idOrSlug)) {
    return Restaurant.findById(idOrSlug).lean();
  }
  return Restaurant.findOne({ slug: idOrSlug }).lean();
}

// ------------- Nearby -------------
/**
 * Nearby restaurants ordered by distance using $geoNear on 2dsphere index.
 */
async function getNearbyRestaurants({ lat, lng, radiusKm = 5, limit = 50, filters = {} }) {
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

  const results = await Restaurant.aggregate(pipeline);
  return results;
}

// ------------- BBox (viewport) -------------
async function getByBBox({ minLng, minLat, maxLng, maxLat, limit = 200, filters = {} }) {
  const l = Math.min(coerceInt(limit, 200), 1000);
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

  const items = await Restaurant.find(match).limit(l).lean();
  return items;
}

// ------------- Suggestions -------------
async function suggestRestaurants({ q, limit = 10, city, country }) {
  const l = Math.min(coerceInt(limit, 10), 25);
  const rx = q ? new RegExp(sanitizeRegex(q), 'i') : null;

  const match = { isActive: true };
  if (rx) match.$or = [{ name: rx }, { city: rx }, { cuisines: rx }];
  if (city) match.city = city;
  if (country) match.country = country;

  const items = await Restaurant.find(match)
    .select({ _id: 1, name: 1, slug: 1, city: 1, country: 1, cuisines: 1 })
    .limit(l)
    .lean();

  return items;
}

// ------------- GeoJSON for maps -------------
async function getRestaurantsGeoJSON(params = {}) {
  const { limit = 1000, ...filters } = params;
  const l = Math.min(coerceInt(limit, 1000), 5000);
  const match = buildMatchFromFilters(filters);

  const items = await Restaurant.find(match)
    .select({
      _id: 1,
      name: 1,
      slug: 1,
      city: 1,
      country: 1,
      cuisines: 1,
      price: 1,
      'reviews.averageRating': 1,
      location: 1
    })
    .limit(l)
    .lean();

  const features = items
    .filter((r) => r.location?.type === 'Point' && Array.isArray(r.location.coordinates))
    .map((r) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: r.location.coordinates },
      properties: {
        id: String(r._id),
        name: r.name,
        slug: r.slug,
        city: r.city,
        country: r.country,
        cuisines: r.cuisines || [],
        price: r.price || null,
        rating: r.reviews?.averageRating ?? null
      }
    }));

  return { type: 'FeatureCollection', features };
}

// ------------- Menus -------------
async function getMenus(idOrSlug) {
  const r = await getRestaurantByIdOrSlug(idOrSlug);
  if (!r) return { sections: [] };
  return { sections: Array.isArray(r.menus) ? r.menus : [] };
}

// ------------- Availability -------------
/**
 * Returns seats capacity for slots overlapping a date/time window.
 * Query accepts date (YYYY-MM-DD), optional time (HH:mm), and partySize.
 */
async function getAvailability(idOrSlug, { date, time, partySize = 2 }) {
  const r = await getRestaurantByIdOrSlug(idOrSlug);
  if (!r) return { slots: [] };

  const slots = Array.isArray(r?.availability?.slots) ? r.availability.slots : [];
  if (!date) return { slots };

  const startISO = time ? toISO(`${date}T${time}:00`) : toISO(`${date}T00:00:00`);
  const endISO = time ? toISO(`${date}T${time}:00`) : toISO(`${date}T23:59:59`);

  const filtered = slots.filter((s) => {
    const sStart = toISO(s.startISO);
    const sEnd = toISO(s.endISO);
    if (sEnd < startISO) return false;
    if (sStart > endISO) return false;
    return true;
  });

  // Map to simple availability objects, capacity gating by partySize
  const items = filtered.map((s) => ({
    startISO: s.startISO,
    endISO: s.endISO,
    capacity: s.capacity,
    canBook: s.capacity >= partySize
  }));

  return { slots: items };
}

// ------------- Booking (stub) -------------
async function bookTable(idOrSlug, { date, time, partySize, contact, notes, payment }) {
  const r = await getRestaurantByIdOrSlug(idOrSlug);
  if (!r) return { ok: false, error: 'not_found' };

  const whenISO = time ? toISO(`${date}T${time}:00`) : toISO(`${date}T00:00:00`);
  // In production, check against the chosen slot capacity and persist a Booking model
  const reservation = {
    restaurantId: String(r._id),
    whenISO,
    partySize: coerceInt(partySize, 2),
    contact,
    notes: notes || null,
    state: 'confirmed',
    createdAtISO: toISO(Date.now()),
    payment: payment ? { ...payment, state: 'captured' } : { state: 'pending' }
  };

  return { ok: true, reservation };
}

// ------------- Reviews (create only; list is in details) -------------
async function addReview(idOrSlug, userId, { rating, title, text, photos }) {
  const r = await getRestaurantByIdOrSlug(idOrSlug);
  if (!r) return null;

  // Minimal inline storage; in production keep a separate Review model and recompute aggregates
  const review = {
    userId: new mongoose.Types.ObjectId(userId),
    rating: coerceInt(rating, 5),
    title: title || null,
    text: text || null,
    photos: Array.isArray(photos) ? photos : [],
    createdAtISO: toISO(Date.now())
  };

  const updated = await Restaurant.findByIdAndUpdate(
    r._id,
    { $push: { reviewsList: review }, $set: { 'reviews.averageRating': r.reviews?.averageRating || rating } },
    { new: true }
  ).lean();

  return updated;
}

// ------------- Photos pagination -------------
async function getPhotos(idOrSlug, { page = 1, limit = 24 } = {}) {
  const r = await getRestaurantByIdOrSlug(idOrSlug);
  if (!r) return { items: [], page: 1, limit: 0, total: 0, hasMore: false };

  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 24), 100);
  const all = Array.isArray(r.photos) ? r.photos : [];
  const start = (p - 1) * l;
  const items = all.slice(start, start + l);

  return {
    items,
    page: p,
    limit: l,
    total: all.length,
    hasMore: start + items.length < all.length
  };
}

// ------------- Facets & Trending -------------
async function getFacets({ city, country } = {}) {
  const match = buildMatchFromFilters({ city, country });

  const [cuisineAgg, dietaryAgg, featureAgg, priceAgg] = await Promise.all([
    Restaurant.aggregate([
      { $match: match },
      { $unwind: '$cuisines' },
      { $group: { _id: '$cuisines', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 25 }
    ]),
    Restaurant.aggregate([
      { $match: match },
      { $unwind: '$dietary' },
      { $group: { _id: '$dietary', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 25 }
    ]),
    Restaurant.aggregate([
      { $match: match },
      { $unwind: '$features' },
      { $group: { _id: '$features', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 25 }
    ]),
    Restaurant.aggregate([
      { $match: match },
      {
        $group: {
          _id: null,
          min: { $min: '$price.amount' },
          max: { $max: '$price.amount' }
        }
      }
    ])
  ]);

  return {
    cuisines: cuisineAgg.map((r) => ({ cuisine: r._id, count: r.count })),
    dietary: dietaryAgg.map((r) => ({ dietary: r._id, count: r.count })),
    features: featureAgg.map((r) => ({ feature: r._id, count: r.count })),
    priceRange: priceAgg?.[0] ? { min: priceAgg[0].min ?? 0, max: priceAgg[0].max ?? 0 } : { min: 0, max: 0 }
  };
}

async function getTrending({ city, country, limit = 10 } = {}) {
  const l = Math.min(coerceInt(limit, 10), 50);
  const match = buildMatchFromFilters({ city, country });
  const items = await Restaurant.find(match).sort({ popularity: -1, viewCount: -1 }).limit(l).lean();
  return items;
}

module.exports = {
  listRestaurants,
  getRestaurantByIdOrSlug,
  getNearbyRestaurants,
  getByBBox,
  suggestRestaurants,
  getRestaurantsGeoJSON,
  getMenus,
  getAvailability,
  bookTable,
  addReview,
  getPhotos,
  getFacets,
  getTrending
};
