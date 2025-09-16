// C:\flutterapp\myapp\backend\scripts\seed_airports.js

'use strict';

/**
 * Seed Airports collection with realistic sample data:
 * - GeoJSON Point [lng, lat] for location
 * - IATA (3-letter) and ICAO (4-letter) codes for interop and search
 * - Fields aligned with frontend: name, city, country, tz, popularity, viewCount, isActive
 *
 * Usage:
 *   node scripts/seed_airports.js --reset   # clears Airports before seeding
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_airports.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model path if different in your project
const Airport = require('../models/Airport');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function slugify(str) {
  return String(str || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '')
    .substring(0, 160);
}

// Sample airports (coords are [lng, lat])
const airports = [
  {
    name: 'Manohar International Airport (Mopa)',
    slug: slugify('Manohar International Airport (Mopa)'),
    iata: 'GOX',
    icao: 'VOGA',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.839, 15.723] },
    popularity: 85,
    viewCount: 5600,
    isActive: true,
    metadata: { terminals: 1 }
  },
  {
    name: 'Goa International Airport (Dabolim)',
    slug: slugify('Goa International Airport (Dabolim)'),
    iata: 'GOI',
    icao: 'VOGO',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.831, 15.380] },
    popularity: 88,
    viewCount: 9200,
    isActive: true,
    metadata: { terminals: 1 }
  },
  {
    name: 'Leonardo da Vinci–Fiumicino Airport',
    slug: slugify('Leonardo da Vinci–Fiumicino Airport'),
    iata: 'FCO',
    icao: 'LIRF',
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    location: { type: 'Point', coordinates: [12.250, 41.800] },
    popularity: 98,
    viewCount: 41200,
    isActive: true,
    metadata: { terminals: 4 }
  },
  {
    name: 'Rome Ciampino Airport',
    slug: slugify('Rome Ciampino Airport'),
    iata: 'CIA',
    icao: 'LIRA',
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    location: { type: 'Point', coordinates: [12.595, 41.800] },
    popularity: 74,
    viewCount: 9800,
    isActive: true,
    metadata: { terminals: 1 }
  },
  {
    name: 'Indira Gandhi International Airport',
    slug: slugify('Indira Gandhi International Airport'),
    iata: 'DEL',
    icao: 'VIDP',
    city: 'New Delhi',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [77.103, 28.556] },
    popularity: 99,
    viewCount: 58200,
    isActive: true,
    metadata: { terminals: 3 }
  },
  {
    name: 'Chhatrapati Shivaji Maharaj International Airport',
    slug: slugify('Chhatrapati Shivaji Maharaj International Airport'),
    iata: 'BOM',
    icao: 'VABB',
    city: 'Mumbai',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [72.871, 19.089] },
    popularity: 99,
    viewCount: 62400,
    isActive: true,
    metadata: { terminals: 2 }
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
    await Airport.deleteMany({});
    console.log('Cleared Airports collection');
  }

  // Upsert by IATA to make the script re-runnable safely
  const ops = airports.map((a) => ({
    updateOne: {
      filter: { iata: a.iata },
      update: { $set: a },
      upsert: true
    }
  }));

  const result = await Airport.bulkWrite(ops, { ordered: false });
  const upserts = result.getUpsertedIds ? result.getUpsertedIds().length : 0;
  console.log(
    `Seed complete: matched=${result.matchedCount || 0}, modified=${result.modifiedCount || 0}, upserted=${upserts}`
  );
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
