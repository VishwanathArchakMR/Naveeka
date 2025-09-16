// C:\flutterapp\myapp\backend\scripts\seed_bus_stops.js

'use strict';

/**
 * Seed BusStops collection with realistic sample data:
 * - GeoJSON Point [lng, lat] for location
 * - GTFS-like stop_code and stop_name alignment
 * - Fields aligned with frontend: name, stop_code, city, country, tz, tags, amenities, popularity, viewCount, isActive
 *
 * Usage:
 *   node scripts/seed_bus_stops.js --reset   # clears BusStops before seeding
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_bus_stops.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model path if different in the project
const BusStop = require('../models/BusStop');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function slugify(str) {
  return String(str || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '')
    .substring(0, 160);
}

// Sample bus stops (coords are [lng, lat])
const busStops = [
  {
    name: 'Panaji Bus Stand',
    slug: slugify('Panaji Bus Stand'),
    stop_code: 'GOA-PANAJI-001',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.8275, 15.4989] },
    amenities: ['shelter', 'ticket_counter'],
    tags: ['intercity', 'city_bus'],
    popularity: 82,
    viewCount: 5400,
    isActive: true,
    metadata: { routes: ['GA1', 'GA2', 'GA7'] }
  },
  {
    name: 'Mapusa Bus Stand',
    slug: slugify('Mapusa Bus Stand'),
    stop_code: 'GOA-MAPUSA-001',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.8092, 15.5937] },
    amenities: ['shelter', 'restrooms'],
    tags: ['intercity'],
    popularity: 78,
    viewCount: 3920,
    isActive: true,
    metadata: { routes: ['GA2', 'GA4'] }
  },
  {
    name: 'Campal Stop',
    slug: slugify('Campal Stop'),
    stop_code: 'GOA-CAMPAL-011',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.8118, 15.4939] },
    amenities: ['shelter'],
    tags: ['city_bus'],
    popularity: 61,
    viewCount: 2110,
    isActive: true,
    metadata: { routes: ['GA7'] }
  },
  {
    name: 'Roma Termini (Bus)',
    slug: slugify('Roma Termini (Bus)'),
    stop_code: 'ROM-TER-001',
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    location: { type: 'Point', coordinates: [12.5018, 41.9022] },
    amenities: ['shelter', 'ticket_machine'],
    tags: ['city_bus', 'airport_link'],
    popularity: 95,
    viewCount: 18750,
    isActive: true,
    metadata: { routes: ['H', '64', '40'] }
  },
  {
    name: 'Colosseo (Bus)',
    slug: slugify('Colosseo (Bus)'),
    stop_code: 'ROM-COL-010',
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    location: { type: 'Point', coordinates: [12.4923, 41.8904] },
    amenities: ['shelter'],
    tags: ['tourist_hotspot'],
    popularity: 88,
    viewCount: 13210,
    isActive: true,
    metadata: { routes: ['51', '75', '117'] }
  }
];

async function connect() {
  await mongoose.connect(MONGODB_URI, { family: 4 });
  mongoose.connection.on('error', (err) => {
    console.error('Mongo connection error:', err);
  });
  console.log('Connected to MongoDB:', mongoose.connection.name);
}

async function seed({ reset = false } = {}) {
  if (reset) {
    await BusStop.deleteMany({});
    console.log('Cleared BusStops collection');
  }

  // Upsert by stop_code to make the script re-runnable safely
  const ops = busStops.map((s) => ({
    updateOne: {
      filter: { stop_code: s.stop_code },
      update: { $set: s },
      upsert: true
    }
  }));

  const result = await BusStop.bulkWrite(ops, { ordered: false });
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
