// C:\flutterapp\myapp\backend\scripts\seed_train_stations.js

'use strict';

/**
 * Seed TrainStations collection with realistic sample data:
 * - GeoJSON Point [lng, lat] location
 * - GTFS-like station_code and station_name alignment
 * - Fields aligned with frontend: name, station_code, city, country, tz, tags, amenities, popularity, viewCount, isActive
 *
 * Usage:
 *   node scripts/seed_train_stations.js --reset   # clears TrainStations before seeding
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_train_stations.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model path if different in the project
const TrainStation = require('../models/TrainStation');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function slugify(str) {
  return String(str || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '')
    .substring(0, 160);
}

// Sample train stations (coords are [lng, lat])
const stations = [
  // India (IR codes: MAO, VSG)
  {
    name: 'Madgaon Junction',
    slug: slugify('Madgaon Junction'),
    station_code: 'MAO',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.9733, 15.2725] },
    amenities: ['waiting_room', 'food_court', 'parking'],
    tags: ['junction', 'konkan'],
    popularity: 92,
    viewCount: 31200,
    isActive: true,
    metadata: { operator: 'Indian Railways', zone: 'SWR' }
  },
  {
    name: 'Vasco da Gama',
    slug: slugify('Vasco da Gama'),
    station_code: 'VSG',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.8236, 15.4023] },
    amenities: ['waiting_room', 'wifi'],
    tags: ['terminus', 'airport_link'],
    popularity: 78,
    viewCount: 12650,
    isActive: true,
    metadata: { operator: 'Indian Railways', zone: 'SWR' }
  },

  // Italy (FS stations; using rider-facing codes/slugs)
  {
    name: 'Roma Termini',
    slug: slugify('Roma Termini'),
    station_code: 'ROM-TERM',
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    location: { type: 'Point', coordinates: [12.5018, 41.9022] },
    amenities: ['wifi', 'luggage_storage', 'food_court', 'metro_link'],
    tags: ['hub', 'high_speed'],
    popularity: 99,
    viewCount: 85200,
    isActive: true,
    metadata: { operator: 'Trenitalia', metro: ['A', 'B'] }
  },
  {
    name: 'Roma Tiburtina',
    slug: slugify('Roma Tiburtina'),
    station_code: 'ROM-TIBU',
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    location: { type: 'Point', coordinates: [12.5308, 41.9108] },
    amenities: ['wifi', 'lounge', 'parking'],
    tags: ['high_speed'],
    popularity: 91,
    viewCount: 33200,
    isActive: true,
    metadata: { operator: 'Trenitalia' }
  },

  // Useful regional station near coastal routes
  {
    name: 'Thivim',
    slug: slugify('Thivim'),
    station_code: 'THVM',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.8087, 15.6526] },
    amenities: ['parking'],
    tags: ['konkan'],
    popularity: 70,
    viewCount: 9800,
    isActive: true,
    metadata: { operator: 'Indian Railways', zone: 'KR' }
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
    await TrainStation.deleteMany({});
    console.log('Cleared TrainStations collection');
  }

  // Upsert by station_code to make the script re-runnable safely
  const ops = stations.map((s) => ({
    updateOne: {
      filter: { station_code: s.station_code },
      update: { $set: s },
      upsert: true
    }
  }));

  const result = await TrainStation.bulkWrite(ops, { ordered: false });
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
