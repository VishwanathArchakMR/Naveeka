// C:\flutterapp\myapp\backend\scripts\seed_buses.js

'use strict';

/**
 * Seed Buses collection with realistic sample data:
 * - GTFS-like ordered stops with seq, names, and ISO 8601 arr/dep strings
 * - GeoJSON LineString [ [lng,lat], ... ] for the route
 * - Operator, classes, amenities, fares, popularity metrics, isActive flag
 *
 * Usage:
 *   node scripts/seed_buses.js --reset   # clears Buses before seeding
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_buses.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model path if different in the project
const Bus = require('../models/Bus');
const BusStop = require('../models/BusStop'); // optional: to link stationRefId if exists

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function iso(s) {
  return s; // helper for readability
}

async function connect() {
  await mongoose.connect(MONGODB_URI, { family: 4 });
  mongoose.connection.on('error', (err) => {
    console.error('Mongo connection error:', err);
  });
  console.log('Connected to MongoDB:', mongoose.connection.name);
}

// Optionally resolve stop names to BusStop refs if present
async function refByCode(stop_code) {
  try {
    const doc = await BusStop.findOne({ stop_code }).select('_id').lean();
    return doc ? doc._id : undefined;
  } catch {
    return undefined;
  }
}

async function buildSamples() {
  // Goa: Panaji -> Mapusa -> Calangute
  const goaStops = [
    { seq: 1, stop_code: 'GOA-PANAJI-001', name: 'Panaji Bus Stand', arr: iso('2025-09-20T08:00:00+05:30'), dep: iso('2025-09-20T08:05:00+05:30') },
    { seq: 2, stop_code: 'GOA-MAPUSA-001', name: 'Mapusa Bus Stand', arr: iso('2025-09-20T08:35:00+05:30'), dep: iso('2025-09-20T08:40:00+05:30') },
    { seq: 3, stop_code: 'GOA-CAL-001',   name: 'Calangute Circle',  arr: iso('2025-09-20T09:00:00+05:30'), dep: iso('2025-09-20T09:00:00+05:30') }
  ];

  // Map stop_code to stationRefId if exists
  const goaStopsResolved = await Promise.all(
    goaStops.map(async (s) => ({
      seq: s.seq,
      name: s.name,
      stationRefId: await refByCode(s.stop_code),
      arr: s.arr,
      dep: s.dep,
      platform: undefined,
      distance_km: undefined
    }))
  );

  // Goa route path (approximate) [lng, lat]
  const goaRoute = [
    [73.8275, 15.4989], // Panaji
    [73.8092, 15.5937], // Mapusa
    [73.7550, 15.5439]  // Calangute approx
  ];

  // Rome: Termini -> Colosseo -> Vatican (bus example)
  const romeStops = [
    { seq: 1, stop_code: 'ROM-TER-001', name: 'Roma Termini (Bus)', arr: iso('2025-09-20T09:00:00+02:00'), dep: iso('2025-09-20T09:05:00+02:00') },
    { seq: 2, stop_code: 'ROM-COL-010', name: 'Colosseo (Bus)',      arr: iso('2025-09-20T09:20:00+02:00'), dep: iso('2025-09-20T09:22:00+02:00') },
    { seq: 3, stop_code: 'ROM-VAT-005', name: 'Vaticano (Bus)',      arr: iso('2025-09-20T09:40:00+02:00'), dep: iso('2025-09-20T09:40:00+02:00') }
  ];

  const romeStopsResolved = await Promise.all(
    romeStops.map(async (s) => ({
      seq: s.seq,
      name: s.name,
      stationRefId: await refByCode(s.stop_code),
      arr: s.arr,
      dep: s.dep,
      platform: undefined,
      distance_km: undefined
    }))
  );

  const romeRoute = [
    [12.5018, 41.9022], // Termini
    [12.4923, 41.8904], // Colosseum
    [12.4534, 41.9065]  // Vatican
  ];

  // Build sample buses
  const buses = [
    {
      number: 'GA-EXP-101',
      name: 'Panaji–Calangute Express',
      operator: 'Goa Transit',
      classes: ['STD', 'AC'],
      amenities: ['wifi', 'ac', 'usb_port'],
      policies: { refundPolicy: '24h before departure: 80% refund' },
      serviceDays: { mon: true, tue: true, wed: true, thu: true, fri: true, sat: true, sun: true },
      validity: { startDate: new Date('2025-09-01'), endDate: new Date('2026-03-31') },
      stops: goaStopsResolved,
      fares: [
        { classCode: 'STD', currency: 'INR', min: 60, max: 90 },
        { classCode: 'AC',  currency: 'INR', min: 90, max: 140 }
      ],
      routeShape: goaRoute, // simple polyline alternative
      coordinatesGeoJSON: { type: 'LineString', coordinates: goaRoute },
      rating: 4.5,
      reviews: { averageRating: 4.4, totalReviews: 320 },
      popularity: 78,
      viewCount: 5200,
      isActive: true,
      metadata: { region: 'Goa', tz: 'Asia/Kolkata' }
    },
    {
      number: 'ROM-URB-64',
      name: 'Rome Urban Line 64',
      operator: 'ATAC Roma',
      classes: ['STD'],
      amenities: ['low_floor'],
      policies: { refundPolicy: 'Non-refundable single ride' },
      serviceDays: { mon: true, tue: true, wed: true, thu: true, fri: true, sat: true, sun: true },
      validity: { startDate: new Date('2025-01-01'), endDate: new Date('2026-12-31') },
      stops: romeStopsResolved,
      fares: [{ classCode: 'STD', currency: 'EUR', min: 1.5, max: 1.5 }],
      routeShape: romeRoute,
      coordinatesGeoJSON: { type: 'LineString', coordinates: romeRoute },
      rating: 4.2,
      reviews: { averageRating: 4.0, totalReviews: 2100 },
      popularity: 92,
      viewCount: 38500,
      isActive: true,
      metadata: { region: 'Lazio', tz: 'Europe/Rome' }
    }
  ];

  return buses;
}

async function seed({ reset = false } = {}) {
  if (reset) {
    await Bus.deleteMany({});
    console.log('Cleared Buses collection');
  }

  const buses = await buildSamples();

  // Upsert by number+operator to be re-runnable
  const ops = buses.map((b) => ({
    updateOne: {
      filter: { number: b.number, operator: b.operator },
      update: { $set: b },
      upsert: true
    }
  }));

  const result = await Bus.bulkWrite(ops, { ordered: false });
  const matched = result.matchedCount || 0;
  const modified = result.modifiedCount || 0;
  const upserted = (result.upsertedCount !== undefined ? result.upsertedCount : (result.getUpsertedIds ? result.getUpsertedIds().length : 0)) || 0;
  console.log(`Seed complete: matched=${matched}, modified=${modified}, upserted=${upserted}`);
}

async function main() {
  const args = process.argv.slice(2);
  const reset = args.includes('--reset');

  try {
    await connect();
    await seed({ reset });
  } catch (err) {
    console.error('Seeding error:', err);
    process.exitCode = 1;
  } finally {
    await mongoose.connection.close();
    console.log('MongoDB connection closed');
  }
}

if (require.main === module) {
  main();
}
