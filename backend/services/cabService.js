// C:\flutterapp\myapp\backend\services\cabService.js

'use strict';

const mongoose = require('mongoose');
const CabRide = require('../models/CabRide');          // booking model
const Driver = require('../models/Driver');            // live driver positions
const Payment = require('../models/Payment');          // optional, if present

// ---------- Utility ----------
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

function haversineKm(a, b) {
  const R = 6371;
  const toRad = (x) => (x * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const sa =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(sa), Math.sqrt(1 - sa));
  return R * c;
}

// Example in-memory rate cards per class
const RATE_CARDS = {
  MINI:   { base: 60, perKm: 12, perMin: 1.5, surge: 1.0, currency: 'INR', etaMin: 6 },
  SEDAN:  { base: 80, perKm: 14, perMin: 2.0, surge: 1.0, currency: 'INR', etaMin: 7 },
  SUV:    { base: 120, perKm: 18, perMin: 2.5, surge: 1.0, currency: 'INR', etaMin: 8 },
  LUX:    { base: 220, perKm: 28, perMin: 3.5, surge: 1.2, currency: 'INR', etaMin: 10 }
};

// ---------- Ride Types ----------
async function getRideTypes({ lat, lng }) {
  // Optionally filter by supply: drivers near the coordinate within 3km
  const near = { type: 'Point', coordinates: [coerceFloat(lng, 0), coerceFloat(lat, 0)] };
  const nearbyDrivers = await Driver.find({
    location: {
      $near: {
        $geometry: near,
        $maxDistance: 3000
      }
    },
    isOnline: true
  }).select({ _id: 1, classCode: 1 }).limit(200).lean();

  const availableByClass = new Set(nearbyDrivers.map((d) => d.classCode || 'MINI'));
  const products = Object.keys(RATE_CARDS).map((cc) => ({
    classCode: cc,
    name: cc === 'MINI' ? 'Mini' : cc === 'SEDAN' ? 'Sedan' : cc === 'SUV' ? 'SUV' : 'Luxury',
    etaMin: RATE_CARDS[cc].etaMin,
    available: availableByClass.has(cc)
  }));

  return products;
}

// ---------- Estimates ----------
function estimatePriceAndTime({ pickup, drop, classCode }) {
  const rate = RATE_CARDS[classCode] || RATE_CARDS.MINI;

  let distanceKm = 3;
  if (pickup?.location && drop?.location) {
    distanceKm = haversineKm(
      { lat: pickup.location.lat, lng: pickup.location.lng },
      { lat: drop.location.lat, lng: drop.location.lng }
    );
  }

  // Rough travel time at 24 km/h city average
  const durationMin = Math.max(8, Math.round((distanceKm / 24) * 60));
  const fare = Math.round((rate.base + rate.perKm * distanceKm + rate.perMin * durationMin) * rate.surge);

  return {
    classCode,
    currency: rate.currency,
    distanceKm: Number(distanceKm.toFixed(2)),
    durationMin,
    fareMin: fare,
    surge: rate.surge
  };
}

async function getEstimates({ pickup, drop, classCode }) {
  if (classCode) {
    const only = estimatePriceAndTime({ pickup, drop, classCode });
    return { items: [only], quotedAtISO: toISO(Date.now()), holdExpiryISO: toISO(Date.now() + 10 * 60 * 1000) };
  }
  const items = Object.keys(RATE_CARDS).map((cc) =>
    estimatePriceAndTime({ pickup, drop, classCode: cc })
  );
  return { items, quotedAtISO: toISO(Date.now()), holdExpiryISO: toISO(Date.now() + 10 * 60 * 1000) };
}

// ---------- Rides ----------
async function createRide({
  userId,
  provider = 'demo',
  classCode = 'MINI',
  pickup,   // { address, location:{ lat, lng }, whenISO? }
  drop,     // { address, location:{ lat, lng } }
  waypoints = [],
  payment = null
}) {
  // Find nearest driver candidate for quick acceptance (demo)
  let assignedDriverId = null;
  if (pickup?.location) {
    const candidate = await Driver.findOne({
      isOnline: true,
      classCode,
      location: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [pickup.location.lng, pickup.location.lat]
          },
          $maxDistance: 4000
        }
      }
    }).select({ _id: 1 }).lean();
    assignedDriverId = candidate?._id || null;
  }

  const quote = estimatePriceAndTime({ pickup, drop, classCode });
  const nowISO = toISO(Date.now());

  const doc = await CabRide.create({
    userId,
    provider,
    classCode,
    state: assignedDriverId ? 'confirmed' : 'created',
    createdAtISO: nowISO,
    updatedAtISO: nowISO,
    pickup,
    drop,
    waypoints,
    priceQuote: {
      currency: quote.currency,
      unitAmount: quote.fareMin,
      surge: quote.surge,
      quotedAtISO: nowISO,
      holdExpiryISO: toISO(Date.now() + 15 * 60 * 1000)
    },
    driverId: assignedDriverId,
    live: {
      position: assignedDriverId ? null : null, // to be filled when driver accepts
      lastUpdatedISO: null
    },
    route: drop?.location ? {
      type: 'FeatureCollection',
      features: [
        {
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: [
              [pickup.location.lng, pickup.location.lat],
              [drop.location.lng, drop.location.lat]
            ]
          },
          properties: { classCode, provider }
        }
      ]
    } : null,
    payment: payment ? { ...payment, state: 'pending' } : { state: 'pending' },
    metadata: { demo: true }
  });

  return doc.toObject();
}

async function getRideById(rideId) {
  if (!isObjectId(rideId)) return null;
  return CabRide.findById(rideId).lean();
}

async function getLiveStatus(rideId) {
  const ride = await getRideById(rideId);
  if (!ride) return null;

  // If a driver is assigned, fetch current driver location
  let driver = null;
  if (ride.driverId) {
    driver = await Driver.findById(ride.driverId).select({ _id: 1, location: 1, heading: 1, speedKph: 1, updatedAtISO: 1 }).lean();
  }

  return {
    rideId: String(ride._id),
    state: ride.state,
    position: driver?.location || ride?.live?.position || null,
    heading: driver?.heading || null,
    speedKph: driver?.speedKph || null,
    lastUpdatedISO: driver?.updatedAtISO || ride?.live?.lastUpdatedISO || null
  };
}

async function getRideRoute(rideId) {
  const ride = await getRideById(rideId);
  if (!ride) return null;

  // If already built, return as-is
  if (ride.route?.type === 'FeatureCollection') {
    return ride.route;
  }

  // Fallback build from pickup/drop
  if (ride?.pickup?.location && ride?.drop?.location) {
    return {
      type: 'FeatureCollection',
      features: [
        {
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: [
              [ride.pickup.location.lng, ride.pickup.location.lat],
              [ride.drop.location.lng, ride.drop.location.lat]
            ]
          },
          properties: { rideId: String(ride._id), classCode: ride.classCode, provider: ride.provider }
        }
      ]
    };
  }

  return { type: 'FeatureCollection', features: [] };
}

async function cancelRide(rideId, reason = 'user_canceled') {
  const ride = await CabRide.findOneAndUpdate(
    { _id: rideId, state: { $nin: ['completed', 'canceled'] } },
    { $set: { state: 'canceled', cancelReason: reason, updatedAtISO: toISO(Date.now()) } },
    { new: true }
  ).lean();

  return ride;
}

async function payForRide(rideId, { amount, currency, method, txnRef }) {
  const ride = await getRideById(rideId);
  if (!ride) return null;

  // Optional: create a Payment record
  let paymentRecord = null;
  if (Payment) {
    paymentRecord = await Payment.create({
      rideId: ride._id,
      amount,
      currency,
      method,
      txnRef,
      status: 'captured',
      capturedAtISO: toISO(Date.now())
    });
  }

  const updated = await CabRide.findByIdAndUpdate(
    ride._id,
    { $set: { 'payment.state': 'paid', 'payment.amount': amount, 'payment.currency': currency, updatedAtISO: toISO(Date.now()) } },
    { new: true }
  ).lean();

  return { ride: updated, payment: paymentRecord || null };
}

// ---------- Provider webhooks (demo stub) ----------
async function handleWebhook(provider, payload) {
  // Example provider payload mapping
  // Expect: { rideId, state, driver:{ id, location }, position:{ lng, lat }, etaMin }
  if (!payload?.rideId) return { ok: false };

  const updates = {};
  if (payload.state) updates.state = payload.state;
  if (payload.position?.lng != null && payload.position?.lat != null) {
    updates['live.position'] = { type: 'Point', coordinates: [payload.position.lng, payload.position.lat] };
    updates['live.lastUpdatedISO'] = toISO(Date.now());
  }
  if (payload.driver?.id) {
    updates.driverId = payload.driver.id;
  }

  const ride = await CabRide.findByIdAndUpdate(payload.rideId, { $set: updates }, { new: true }).lean();
  return { ok: true, ride };
}

module.exports = {
  getRideTypes,
  getEstimates,
  createRide,
  getRideById,
  getLiveStatus,
  getRideRoute,
  cancelRide,
  payForRide,
  handleWebhook
};
