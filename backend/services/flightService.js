// C:\flutterapp\myapp\backend\services\flightService.js

'use strict';

const mongoose = require('mongoose');

// Models (paths may differ in the project)
const Flight = require('../models/Flight');
const Airport = require('../models/Airport');

// Optional booking model; handled defensively if absent
let FlightBooking = null;
try {
  // Define ../models/FlightBooking in the project to persist bookings
  FlightBooking = require('../models/FlightBooking'); // eslint-disable-line global-require
} catch (e) {
  FlightBooking = null;
}

// ---------- Helpers ----------
function isObjectId(v) {
  return mongoose.Types.ObjectId.isValid(v);
}

function coerceInt(v, def) {
  const n = parseInt(v, 10);
  return Number.isFinite(n) && n > 0 ? n : def;
}

function toISO(d) {
  return new Date(d).toISOString();
}

function dayBoundsISO(dateYMD) {
  const start = new Date(`${dateYMD}T00:00:00.000Z`);
  const end = new Date(start.getTime() + 24 * 60 * 60 * 1000 - 1);
  return { start, end };
}

function firstSegment(flight) {
  const segs = flight?.slices?.[0]?.segments || [];
  return segs.length ? segs[0] : null;
}

function lastSegment(flight) {
  const segs = flight?.slices?.[0]?.segments || [];
  return segs.length ? segs[segs.length - 1] : null;
}

const AIRLINES = {
  AI: 'Air India',
  '6E': 'IndiGo',
  AZ: 'ITA Airways',
  UK: 'Vistara'
};

// ---------- Core: Search ----------
/**
 * Search flights by tripType and slices:
 * tripType: 'ONE_WAY' | 'ROUND_TRIP' | 'MULTI_CITY'
 * slices: [{ origin:{iata}, destination:{iata}, departureISO }]
 * pax: { adt, cnn, inf }
 * cabin: 'ECONOMY' | 'PREMIUM_ECONOMY' | 'BUSINESS' | 'FIRST'
 * maxStops, sort: 'price'|'duration'|'departure'|'popularity'
 */
async function searchFlights({ tripType = 'ONE_WAY', slices = [], pax, cabin, maxStops, sort = 'price' }) {
  if (!Array.isArray(slices) || slices.length === 0) {
    return { trips: [] };
  }

  // Helper to query a single slice window
  async function searchSlice(slice) {
    const { origin, destination, departureISO } = slice || {};
    const from = origin?.iata?.toUpperCase();
    const to = destination?.iata?.toUpperCase();
    if (!from || !to || !departureISO) return [];

    const d = new Date(departureISO);
    const ymd = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
    const { start, end } = dayBoundsISO(ymd);

    // Match seeded structure: top-level from/to and first segment departure window
    const match = {
      isActive: true,
      from,
      to,
      'slices.0.segments.0.departureISO': { $gte: start, $lte: end }
    };

    // Stops filter: count inferred from segments length (0 stop => 1 segment, 1 stop => 2 segments, etc.)
    if (Number.isFinite(maxStops)) {
      match.$expr = {
        $lte: [
          { $subtract: [{ $size: { $ifNull: ['$slices.0.segments', []] } }, 1] },
          maxStops
        ]
      };
    }

    const sortStage = (() => {
      switch (sort) {
        case 'duration':
          return { 'slices.0.segments.0.durationMin': 1, 'price.amount': 1 };
        case 'departure':
          return { 'slices.0.segments.0.departureISO': 1 };
        case 'popularity':
          return { popularity: -1, viewCount: -1, 'price.amount': 1 };
        case 'price':
        default:
          return { 'price.amount': 1, 'slices.0.segments.0.departureISO': 1 };
      }
    })();

    const items = await Flight.find(match).sort(sortStage).limit(200).lean();
    return items;
  }

  if (tripType === 'ONE_WAY') {
    const items = await searchSlice(slices[0]);
    return { trips: [{ sliceIndex: 0, items }] };
  }

  if (tripType === 'ROUND_TRIP') {
    const outItems = await searchSlice(slices[0]);
    const inItems = await searchSlice(slices[1]);
    return { trips: [{ sliceIndex: 0, items: outItems }, { sliceIndex: 1, items: inItems }] };
  }

  // MULTI_CITY: independent results per slice
  const trips = [];
  for (let i = 0; i < slices.length; i++) {
    // eslint-disable-next-line no-await-in-loop
    const items = await searchSlice(slices[i]);
    trips.push({ sliceIndex: i, items });
  }
  return { trips };
}

// ---------- Suggestions ----------
/**
 * Suggest airports, airlines, and routes
 * types: 'airport,airline,route' subset
 */
async function suggest({ q = '', types = 'airport,airline,route', limit = 10 }) {
  const l = Math.min(coerceInt(limit, 10), 25);
  const typeSet = new Set(String(types).split(',').map((s) => s.trim()));

  const result = {};

  if (typeSet.has('airport')) {
    const rx = q ? new RegExp(String(q).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') : null;
    const amatch = rx
      ? { isActive: true, $or: [{ name: rx }, { city: rx }, { country: rx }, { iata: rx }] }
      : { isActive: true };
    // lightweight projection
    // name, city, country, iata, location
    result.airports = await Airport.find(amatch)
      .select({ _id: 1, name: 1, city: 1, country: 1, iata: 1, location: 1 })
      .limit(l)
      .lean();
  }

  if (typeSet.has('airline')) {
    const rx = q ? new RegExp(String(q).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') : null;
    const entries = Object.entries(AIRLINES)
      .filter(([code, name]) => !rx || rx.test(code) || rx.test(name))
      .slice(0, l)
      .map(([code, name]) => ({ code, name }));
    result.airlines = entries;
  }

  if (typeSet.has('route')) {
    const rx = q ? new RegExp(String(q).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i') : null;
    const routes = await Flight.aggregate([
      {
        $project: {
          _id: 0,
          from: 1,
          to: 1,
          route: { $concat: ['$from', '-', '$to'] }
        }
      },
      { $group: { _id: '$route', from: { $first: '$from' }, to: { $first: '$to' }, count: { $sum: 1 } } },
      ...(rx ? [{ $match: { _id: rx } }] : []),
      { $sort: { count: -1 } },
      { $limit: l }
    ]);
    result.routes = routes.map((r) => ({ from: r.from, to: r.to, count: r.count }));
  }

  return result;
}

// ---------- Airlines ----------
async function getAirlines() {
  // Could be backed by a collection/cache in production
  return Object.entries(AIRLINES).map(([code, name]) => ({ code, name }));
}

// ---------- Quote / Reprice ----------
/**
 * getQuote: If offerId (offerKey or _id) is provided, return priced offer with hold expiry.
 * Otherwise, accepts segments and travelers and returns a computed price stub.
 */
async function getQuote({ offerId, travelers = [], currency }) {
  let offer = null;

  if (offerId) {
    // support both DB _id and offerKey
    if (isObjectId(offerId)) {
      offer = await Flight.findById(offerId).lean();
    }
    if (!offer) {
      offer = await Flight.findOne({ offerKey: offerId }).lean();
    }
  }

  let unitAmount = 0;
  let curr = currency || 'INR';

  if (offer?.price) {
    unitAmount = offer.price.amount || 0;
    curr = currency || offer.price.currency || curr;
  } else if (offer) {
    // fallback if price missing
    unitAmount = 0;
  } else {
    // compute stub when no offer; for demo return 0
    unitAmount = 0;
  }

  const qty = Math.max(coerceInt(travelers.length || 1, 1), 1);
  const totalAmount = unitAmount * qty;

  return {
    offerId: offer?._id ? String(offer._id) : offerId || null,
    carrier: offer?.carrier || null,
    number: offer?.number || null,
    cabin: offer?.slices?.[0]?.segments?.[0]?.cabin || 'ECONOMY',
    price: { currency: curr, unitAmount, totalAmount },
    holdExpiryISO: toISO(Date.now() + 15 * 60 * 1000)
  };
}

// ---------- Booking ----------
async function bookFlight({ offerId, contact, travelers, payment }) {
  const quote = await getQuote({ offerId, travelers, currency: payment?.currency });
  const bookingPayload = {
    offerId: quote.offerId,
    contact,
    travelers,
    price: quote.price,
    state: 'confirmed',
    createdAtISO: toISO(Date.now()),
    payment: payment ? { ...payment, state: 'captured' } : { state: 'pending' }
  };

  if (FlightBooking) {
    const saved = await FlightBooking.create(bookingPayload);
    return saved.toObject();
  }
  // Fallback without persistence
  return { _id: null, ...bookingPayload };
}

// ---------- Details / Route ----------
async function getFlightById(idOrOfferKey) {
  if (!idOrOfferKey) return null;
  if (isObjectId(idOrOfferKey)) {
    return Flight.findById(idOrOfferKey).lean();
  }
  return Flight.findOne({ offerKey: idOrOfferKey }).lean();
}

async function getFlightRoute(idOrOfferKey) {
  const flight = await getFlightById(idOrOfferKey);
  if (!flight) return null;

  // Use stored GeoJSON if present
  if (flight.routeGeoJSON?.type) {
    if (flight.routeGeoJSON.type === 'FeatureCollection') {
      return flight.routeGeoJSON;
    }
    // If a bare geometry, wrap it
    return {
      type: 'FeatureCollection',
      features: [{ type: 'Feature', geometry: flight.routeGeoJSON, properties: { id: String(flight._id) } }]
    };
  }

  // Fallback: build from first/last segment airport coords
  const segA = firstSegment(flight);
  const segB = lastSegment(flight);
  const fromIATA = segA?.from?.iata || flight.from;
  const toIATA = segB?.to?.iata || flight.to;

  const [fromApt, toApt] = await Promise.all([
    Airport.findOne({ iata: fromIATA }).select({ location: 1 }).lean(),
    Airport.findOne({ iata: toIATA }).select({ location: 1 }).lean()
  ]);

  const a = fromApt?.location?.coordinates;
  const b = toApt?.location?.coordinates;
  if (Array.isArray(a) && Array.isArray(b)) {
    return {
      type: 'FeatureCollection',
      features: [
        {
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: [a, b] },
          properties: { id: String(flight._id) }
        }
      ]
    };
  }

  return { type: 'FeatureCollection', features: [] };
}

// ---------- Live status (stub) ----------
async function getLiveStatus({ carrier, number, date }) {
  // Integrate real-time provider here; return a stub for now
  return {
    carrier: String(carrier || '').toUpperCase(),
    number: String(number || ''),
    date: date || null,
    departure: { airport: null, scheduledISO: null, actualISO: null, terminal: null, gate: null },
    arrival: { airport: null, scheduledISO: null, actualISO: null, terminal: null, gate: null },
    status: 'unknown',
    lastUpdatedISO: toISO(Date.now())
  };
}

module.exports = {
  searchFlights,
  suggest,
  getAirlines,
  getQuote,
  bookFlight,
  getFlightById,
  getFlightRoute,
  getLiveStatus
};
