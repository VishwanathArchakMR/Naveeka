// C:\flutterapp\myapp\backend\scripts\seed_trains.js

'use strict';

/**
 * Seed Trains collection with realistic sample data:
 * - GTFS-like ordered stops with seq and ISO 8601 arr/dep strings
 * - GeoJSON LineString [ [lng,lat], ... ] for route geometry
 * - Operator, classes, amenities, fares, popularity metrics, isActive flag
 * - Service days and validity windows for timetable alignment
 *
 * Usage:
 *   node scripts/seed_trains.js --reset   # clears Trains before seeding
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_trains.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Models (adjust paths if different in your project)
const Train = require('../models/Train');
const TrainStation = require('../models/TrainStation'); // optional: to link stationRefId if exists

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function iso(s) {
  return s; // helper for readability in seeds
}

async function connect() {
  await mongoose.connect(MONGODB_URI, { family: 4 });
  mongoose.connection.on('error', (err) => {
    console.error('Mongo connection error:', err);
  });
  console.log('Connected to MongoDB:', mongoose.connection.name);
}

// Resolve station_code to TrainStation _id for clean linking
async function stationRefByCode(station_code) {
  try {
    const doc = await TrainStation.findOne({ station_code }).select('_id').lean();
    return doc ? doc._id : undefined;
  } catch {
    return undefined;
  }
}

async function buildSamples() {
  // India: MAO -> THVM -> VSG (Konkan coastal segment)
  const inStops = [
    { seq: 1, station_code: 'MAO', name: 'Madgaon Junction', arr: iso('2025-09-21T07:45:00+05:30'), dep: iso('2025-09-21T07:55:00+05:30') },
    { seq: 2, station_code: 'THVM', name: 'Thivim',           arr: iso('2025-09-21T08:35:00+05:30'), dep: iso('2025-09-21T08:37:00+05:30') },
    { seq: 3, station_code: 'VSG',  name: 'Vasco da Gama',    arr: iso('2025-09-21T09:25:00+05:30'), dep: iso('2025-09-21T09:25:00+05:30') }
  ];

  const inStopsResolved = await Promise.all(
    inStops.map(async (s) => ({
      seq: s.seq,
      name: s.name,
      stationRefId: await stationRefByCode(s.station_code),
      arr: s.arr,
      dep: s.dep,
      platform: undefined,
      distance_km: undefined
    }))
  );

  // Route (approx) [lng, lat]
  const inRoute = [
    [73.9733, 15.2725], // MAO
    [73.8087, 15.6526], // THVM
    [73.8236, 15.4023]  // VSG
  ];

  // Italy: Roma Termini -> Roma Tiburtina (HS shuttle segment)
  const itStops = [
    { seq: 1, station_code: 'ROM-TERM', name: 'Roma Termini',   arr: iso('2025-09-22T09:00:00+02:00'), dep: iso('2025-09-22T09:05:00+02:00') },
    { seq: 2, station_code: 'ROM-TIBU', name: 'Roma Tiburtina', arr: iso('2025-09-22T09:15:00+02:00'), dep: iso('2025-09-22T09:15:00+02:00') }
  ];

  const itStopsResolved = await Promise.all(
    itStops.map(async (s) => ({
      seq: s.seq,
      name: s.name,
      stationRefId: await stationRefByCode(s.station_code),
      arr: s.arr,
      dep: s.dep,
      platform: undefined,
      distance_km: undefined
    }))
  );

  const itRoute = [
    [12.5018, 41.9022], // Termini
    [12.5308, 41.9108]  // Tiburtina
  ];

  // Build train docs
  const trains = [
    {
      number: '101',
      name: 'Konkan Coastal Express',
      operator: 'Indian Railways',
      classes: ['2S', 'SL', '3A'],
      amenities: ['pantry', 'usb_port'],
      policies: { refundPolicy: 'As per IRCTC rules' },
      serviceDays: { mon: true, tue: true, wed: true, thu: true, fri: true, sat: true, sun: true },
      validity: { startDate: new Date('2025-09-01'), endDate: new Date('2026-03-31') },
      stops: inStopsResolved,
      fares: [
        { classCode: '2S', currency: 'INR', min: 45, max: 65 },
        { classCode: 'SL', currency: 'INR', min: 110, max: 160 },
        { classCode: '3A', currency: 'INR', min: 320, max: 420 }
      ],
      coordinatesGeoJSON: { type: 'LineString', coordinates: inRoute },
      rating: 4.3,
      reviews: { averageRating: 4.2, totalReviews: 860 },
      popularity: 84,
      viewCount: 22850,
      isActive: true,
      metadata: { region: 'Konkan', tz: 'Asia/Kolkata', color: '#1565C0' }
    },
    {
      number: 'FR-AV-700',
      name: 'Roma HS Shuttle',
      operator: 'Trenitalia',
      classes: ['STD', 'PRM'],
      amenities: ['wifi', 'low_floor'],
      policies: { refundPolicy: 'Non-refundable saver; Flex fare changeable' },
      serviceDays: { mon: true, tue: true, wed: true, thu: true, fri: true, sat: true, sun: true },
      validity: { startDate: new Date('2025-01-01'), endDate: new Date('2026-12-31') },
      stops: itStopsResolved,
      fares: [
        { classCode: 'STD', currency: 'EUR', min: 2.0, max: 3.5 },
        { classCode: 'PRM', currency: 'EUR', min: 3.0, max: 5.0 }
      ],
      coordinatesGeoJSON: { type: 'LineString', coordinates: itRoute },
      rating: 4.4,
      reviews: { averageRating: 4.3, totalReviews: 1320 },
      popularity: 90,
      viewCount: 38500,
      isActive: true,
      metadata: { region: 'Lazio', tz: 'Europe/Rome', color: '#C62828' }
    }
  ];

  return trains;
}

async function seed({ reset = false } = {}) {
  if (reset) {
    await Train.deleteMany({});
    console.log('Cleared Trains collection');
  }

  const trains = await buildSamples();

  // Upsert by number+operator to be re-runnable
  const ops = trains.map((t) => ({
    updateOne: {
      filter: { number: t.number, operator: t.operator },
      update: { $set: t },
      upsert: true
    }
  }));

  const result = await Train.bulkWrite(ops, { ordered: false });
  const matched = result.matchedCount || 0;
  const modified = result.modifiedCount || 0;
  const upserted =
    (result.upsertedCount !== undefined
      ? result.upsertedCount
      : (result.getUpsertedIds ? result.getUpsertedIds().length : 0)) || 0;

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
