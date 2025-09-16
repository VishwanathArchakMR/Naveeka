// C:\flutterapp\myapp\backend\services\hotelService.js

'use strict';

const mongoose = require('mongoose');
const Hotel = require('../models/Hotel');

// Optional booking model if present in the project
let HotelBooking = null;
try {
  HotelBooking = require('../models/HotelBooking'); // eslint-disable-line global-require
} catch (e) {
  HotelBooking = null;
}

// ----------------- Helpers -----------------
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

function toISO(d) {
  return new Date(d).toISOString();
}

function nightsBetween(checkIn, checkOut) {
  if (!checkIn || !checkOut) return 0;
  const a = new Date(checkIn);
  const b = new Date(checkOut);
  const ms = b.getTime() - a.getTime();
  return ms > 0 ? Math.ceil(ms / (24 * 60 * 60 * 1000)) : 0;
}

function sanitizeRegex(s) {
  return s ? String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') : '';
}

function buildMatchFromFilters(filters = {}) {
  const {
    city,
    country,
    stars,
    tags,
    amenities,
    minPrice,
    maxPrice,
    minRating
  } = filters;

  const match = { isActive: true };

  if (city) match.city = city;
  if (country) match.country = country;

  if (stars != null) {
    // supports single or "3,4,5"
    const arr = Array.isArray(stars) ? stars : String(stars).split(',').map((x) => parseInt(x, 10)).filter((x) => Number.isFinite(x));
    if (arr.length) match.stars = { $in: arr };
  }

  if (tags) {
    const arr = Array.isArray(tags) ? tags : String(tags).split(',').map((s) => s.trim()).filter(Boolean);
    if (arr.length) match.tags = { $all: arr };
  }

  if (amenities) {
    const arr = Array.isArray(amenities) ? amenities : String(amenities).split(',').map((s) => s.trim()).filter(Boolean);
    if (arr.length) match.amenities = { $all: arr };
  }

  if (minPrice != null || maxPrice != null) {
    match['price.amount'] = {};
    if (minPrice != null) match['price.amount'].$gte = coerceFloat(minPrice, 0);
    if (maxPrice != null) match['price.amount'].$lte = coerceFloat(maxPrice, Number.MAX_SAFE_INTEGER);
  }

  if (minRating != null) {
    match['reviews.averageRating'] = { $gte: coerceFloat(minRating, 0) };
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
    case 'stars_desc':
      return { stars: -1, 'reviews.averageRating': -1 };
    case 'newest':
      return { _id: -1 };
    case 'popularity':
      return { popularity: -1, viewCount: -1 };
    default:
      return { popularity: -1, viewCount: -1 };
  }
}

// ----------------- Core: list/search -----------------
async function listHotels(params = {}) {
  const {
    page = 1,
    limit = 20,
    sort,
    city,
    country,
    stars,
    tags,
    amenities,
    minPrice,
    maxPrice,
    minRating
  } = params;

  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 20), 100);
  const skip = (p - 1) * l;

  const match = buildMatchFromFilters({
    city,
    country,
    stars,
    tags,
    amenities,
    minPrice,
    maxPrice,
    minRating
  });

  const [items, total] = await Promise.all([
    Hotel.find(match).sort(buildSort(sort)).skip(skip).limit(l).lean(),
    Hotel.countDocuments(match)
  ]);

  return {
    items,
    page: p,
    limit: l,
    total,
    hasMore: skip + items.length < total
  };
}

// ----------------- Details -----------------
async function getHotelByIdOrSlug(idOrSlug) {
  if (!idOrSlug) return null;
  if (isObjectId(idOrSlug)) {
    return Hotel.findById(idOrSlug).lean();
  }
  return Hotel.findOne({ slug: idOrSlug }).lean();
}

// ----------------- Nearby (geo) -----------------
/**
 * Nearby hotels ordered by distance using $geoNear; requires a 2dsphere index on "location".
 */
async function getNearbyHotels({ lat, lng, radiusKm = 5, limit = 50, filters = {} }) {
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

  const results = await Hotel.aggregate(pipeline);
  return results;
}

// ----------------- BBox (viewport) -----------------
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

  const items = await Hotel.find(match).limit(l).lean();
  return items;
}

// ----------------- Suggestions -----------------
async function suggestHotels({ q, limit = 10, city, country }) {
  const l = Math.min(coerceInt(limit, 10), 25);
  const rx = q ? new RegExp(sanitizeRegex(q), 'i') : null;

  const match = { isActive: true };
  if (rx) {
    match.$or = [{ name: rx }, { city: rx }, { tags: rx }];
  }
  if (city) match.city = city;
  if (country) match.country = country;

  const items = await Hotel.find(match)
    .select({ _id: 1, name: 1, slug: 1, city: 1, country: 1, stars: 1, tags: 1 })
    .limit(l)
    .lean();

  return items;
}

// ----------------- GeoJSON for maps -----------------
async function getHotelsGeoJSON(params = {}) {
  const { limit = 1000, ...filters } = params;
  const l = Math.min(coerceInt(limit, 1000), 5000);
  const match = buildMatchFromFilters(filters);

  const items = await Hotel.find(match)
    .select({
      _id: 1,
      name: 1,
      slug: 1,
      city: 1,
      country: 1,
      stars: 1,
      'price.amount': 1,
      'price.currency': 1,
      'reviews.averageRating': 1,
      location: 1
    })
    .limit(l)
    .lean();

  const features = items
    .filter((h) => h.location?.type === 'Point' && Array.isArray(h.location.coordinates))
    .map((h) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: h.location.coordinates },
      properties: {
        id: String(h._id),
        name: h.name,
        slug: h.slug,
        city: h.city,
        country: h.country,
        stars: h.stars ?? null,
        price: h.price || null,
        rating: h.reviews?.averageRating ?? null
      }
    }));

  return { type: 'FeatureCollection', features };
}

// ----------------- Availability & Rooms -----------------
/**
 * Filters ratePlans by ISO validity window against requested check-in/out, and returns rooms.
 */
async function getAvailability({ idOrSlug, checkIn, checkOut, adults = 2, children = 0 }) {
  const hotel = await getHotelByIdOrSlug(idOrSlug);
  if (!hotel) return { rooms: [], ratePlans: [] };

  const nights = nightsBetween(checkIn, checkOut);

  const validPlans = Array.isArray(hotel.ratePlans)
    ? hotel.ratePlans.filter((rp) => {
        if (!rp.validFromISO || !rp.validToISO) return true;
        const start = new Date(rp.validFromISO).toISOString();
        const end = new Date(rp.validToISO).toISOString();
        const reqIn = checkIn ? new Date(checkIn).toISOString() : null;
        const reqOut = checkOut ? new Date(checkOut).toISOString() : null;
        if (reqIn && end < reqIn) return false;
        if (reqOut && start > reqOut) return false;
        return true;
      })
    : [];

  // In a real system, occupancy would be checked per room; here we pass through seeded rooms.
  const rooms = Array.isArray(hotel.rooms) ? hotel.rooms : [];

  return {
    hotelId: String(hotel._id),
    nights,
    rooms,
    ratePlans: validPlans
  };
}

async function getRooms({ idOrSlug, checkIn, checkOut, adults = 2, children = 0 }) {
  const avail = await getAvailability({ idOrSlug, checkIn, checkOut, adults, children });
  return { rooms: avail.rooms, nights: avail.nights };
}

// ----------------- Quote & Booking -----------------
/**
 * Quote: compute total = sum(selected roomCodes nightly price from a chosen ratePlan) * nights * quantity.
 * Body is flexible: either pick a single ratePlanId + roomCodes, or pass explicit per-room quantities.
 */
async function getQuote({
  idOrSlug,
  checkIn,
  checkOut,
  ratePlanId,          // optional: prefer a specific plan
  roomCodes = [],      // array of room code strings
  quantities = {},     // optional: { [roomCode]: count }
  currency             // optional currency override
}) {
  const hotel = await getHotelByIdOrSlug(idOrSlug);
  if (!hotel) return null;

  const nights = nightsBetween(checkIn, checkOut);
  if (nights <= 0) {
    return { error: 'Invalid date range', nights: 0 };
  }

  const plans = Array.isArray(hotel.ratePlans) ? hotel.ratePlans : [];
  const selectedPlan = ratePlanId
    ? plans.find((p) => p.id === ratePlanId)
    : plans;

  if (!selectedPlan) return { error: 'No rate plans', nights };

  const roomMap = new Map((hotel.rooms || []).map((r) => [r.code, r]));
  const chosenCodes = roomCodes.length ? roomCodes : (selectedPlan.roomCodes || []);

  // Basic pricing: use plan.pricePerNight per roomCode equally (demo seed)
  const unitPerNight = selectedPlan.pricePerNight || 0;
  let totalRooms = 0;
  for (const code of chosenCodes) {
    const qty = Number.isFinite(quantities[code]) ? coerceInt(quantities[code], 1) : 1;
    totalRooms += qty;
  }

  const unitAmount = unitPerNight;
  const totalAmount = unitPerNight * nights * Math.max(totalRooms, 1);
  const curr = currency || selectedPlan.currency || hotel.price?.currency || 'INR';

  return {
    hotelId: String(hotel._id),
    name: hotel.name,
    slug: hotel.slug,
    checkIn,
    checkOut,
    nights,
    ratePlanId: selectedPlan.id,
    roomCodes: chosenCodes,
    price: { currency: curr, unitAmount, totalAmount },
    holdExpiryISO: toISO(Date.now() + 15 * 60 * 1000)
  };
}

async function bookHotel({ idOrSlug, checkIn, checkOut, guests, quote, contact, payment }) {
  const hotel = await getHotelByIdOrSlug(idOrSlug);
  if (!hotel) return null;

  const bookingPayload = {
    hotelId: String(hotel._id),
    checkIn,
    checkOut,
    guests,
    quote,
    contact,
    state: 'confirmed',
    createdAtISO: toISO(Date.now()),
    payment: payment ? { ...payment, state: 'captured' } : { state: 'pending' }
  };

  if (HotelBooking) {
    const saved = await HotelBooking.create(bookingPayload);
    return saved.toObject();
  }
  return { _id: null, ...bookingPayload };
}

// ----------------- Photos -----------------
async function getPhotos({ idOrSlug, page = 1, limit = 24 }) {
  const h = await getHotelByIdOrSlug(idOrSlug);
  if (!h) return { items: [], page: 1, limit: 0, total: 0, hasMore: false };

  const p = coerceInt(page, 1);
  const l = Math.min(coerceInt(limit, 24), 100);
  const all = Array.isArray(h.photos) ? h.photos : [];
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

// ----------------- Facets & Trending -----------------
async function getFacets({ city, country } = {}) {
  const match = buildMatchFromFilters({ city, country });

  const [starsAgg, amenityAgg, priceAgg] = await Promise.all([
    Hotel.aggregate([
      { $match: match },
      { $group: { _id: '$stars', count: { $sum: 1 } } },
      { $sort: { _id: 1 } }
    ]),
    Hotel.aggregate([
      { $match: match },
      { $unwind: '$amenities' },
      { $group: { _id: '$amenities', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 25 }
    ]),
    Hotel.aggregate([
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
    stars: starsAgg.map((r) => ({ stars: r._id, count: r.count })),
    topAmenities: amenityAgg.map((r) => ({ amenity: r._id, count: r.count })),
    priceRange: priceAgg?.[0] ? { min: priceAgg[0].min ?? 0, max: priceAgg[0].max ?? 0 } : { min: 0, max: 0 }
  };
}

async function getTrending({ city, country, limit = 10 } = {}) {
  const l = Math.min(coerceInt(limit, 10), 50);
  const match = buildMatchFromFilters({ city, country });
  const items = await Hotel.find(match).sort({ popularity: -1, viewCount: -1 }).limit(l).lean();
  return items;
}

module.exports = {
  listHotels,
  getHotelByIdOrSlug,
  getNearbyHotels,
  getByBBox,
  suggestHotels,
  getHotelsGeoJSON,
  getAvailability,
  getRooms,
  getQuote,
  bookHotel,
  getPhotos,
  getFacets,
  getTrending
};
