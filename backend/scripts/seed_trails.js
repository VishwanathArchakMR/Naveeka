// C:\flutterapp\myapp\backend\scripts\seed_trails.js

'use strict';

/**
 * Seed Trails collection with realistic sample data:
 * - RFC 7946 GeoJSON LineStrings [ [lng,lat], ... ] for route geometry
 * - GeoJSON Point for start location
 * - Difficulty, lengthKm, elevGainM, tags, conditions (ISO 8601), elevationProfile
 * - Reviews aggregate, photos, popularity/view counts
 *
 * Usage:
 *   node scripts/seed_trails.js --reset
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_trails.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model path if different in the project
const Trail = require('../models/Trail');

const MONGODB_URI =
  process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function slugify(str) {
  return String(str || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '')
    .substring(0, 160);
}

function iso(d) {
  return new Date(d).toISOString();
}

// Sample trails
const nowISO = new Date().toISOString();

const trails = [
  {
    name: 'Altinho Hill Loop',
    slug: slugify('Altinho Hill Loop'),
    description:
      'Gentle urban loop over Altinho Hill with viewpoints over Panaji and the Mandovi river.',
    difficulty: 'easy',
    lengthKm: 4.2,
    elevGainM: 120,
    tags: ['urban', 'viewpoints', 'family'],
    city: 'Goa',
    country: 'India',
    region: 'Goa',
    tz: 'Asia/Kolkata',
    startLocation: { type: 'Point', coordinates: [73.8278, 15.4989] }, // Panaji [lng, lat]
    routeGeoJSON: {
      type: 'LineString',
      coordinates: [
        [73.8278, 15.4989],
        [73.8239, 15.5052],
        [73.8205, 15.5026],
        [73.8250, 15.4983],
        [73.8278, 15.4989]
      ]
    },
    elevationProfile: [
      { distanceKm: 0.0, elevationM: 5 },
      { distanceKm: 1.0, elevationM: 60 },
      { distanceKm: 2.1, elevationM: 110 },
      { distanceKm: 3.4, elevationM: 70 },
      { distanceKm: 4.2, elevationM: 8 }
    ],
    conditions: {
      status: 'open',
      lastUpdatedISO: nowISO,
      notes: 'Clear path, occasional scooters near residential sections.'
    },
    photos: [
      'https://example-cdn/trails/altinho_1.jpg',
      'https://example-cdn/trails/altinho_2.jpg'
    ],
    reviews: { averageRating: 4.3, totalReviews: 240 },
    popularity: 71,
    viewCount: 5400,
    isActive: true,
    metadata: { surface: 'mixed', shaded: true }
  },
  {
    name: 'Chapora Fort Trail',
    slug: slugify('Chapora Fort Trail'),
    description:
      'Short climb to Chapora Fort with sweeping views of the Chapora river and coastline.',
    difficulty: 'moderate',
    lengthKm: 2.5,
    elevGainM: 80,
    tags: ['viewpoints', 'sunset', 'historic'],
    city: 'Goa',
    country: 'India',
    region: 'Goa',
    tz: 'Asia/Kolkata',
    startLocation: { type: 'Point', coordinates: [73.7364, 15.6037] },
    routeGeoJSON: {
      type: 'LineString',
      coordinates: [
        [73.7364, 15.6037],
        [73.7350, 15.6030],
        [73.7342, 15.6048],
        [73.7336, 15.6061],
        [73.7328, 15.6067]
      ]
    },
    elevationProfile: [
      { distanceKm: 0.0, elevationM: 12 },
      { distanceKm: 0.8, elevationM: 45 },
      { distanceKm: 1.5, elevationM: 72 },
      { distanceKm: 2.5, elevationM: 85 }
    ],
    conditions: {
      status: 'open',
      lastUpdatedISO: nowISO,
      notes: 'Some rocky steps; shoes recommended.'
    },
    photos: [
      'https://example-cdn/trails/chapora_1.jpg',
      'https://example-cdn/trails/chapora_2.jpg'
    ],
    reviews: { averageRating: 4.6, totalReviews: 880 },
    popularity: 88,
    viewCount: 18250,
    isActive: true,
    metadata: { bestTime: 'sunset' }
  },
  {
    name: 'Anjuna Coastal Walk',
    slug: slugify('Anjuna Coastal Walk'),
    description:
      'Scenic coastal walk from Anjuna to Vagator with black rocks and tide pools.',
    difficulty: 'easy',
    lengthKm: 5.8,
    elevGainM: 95,
    tags: ['coastal', 'photography'],
    city: 'Goa',
    country: 'India',
    region: 'Goa',
    tz: 'Asia/Kolkata',
    startLocation: { type: 'Point', coordinates: [73.7389, 15.5743] },
    routeGeoJSON: {
      type: 'LineString',
      coordinates: [
        [73.7389, 15.5743],
        [73.7372, 15.5790],
        [73.7350, 15.5840],
        [73.7331, 15.5888],
        [73.7312, 15.5930]
      ]
    },
    elevationProfile: [
      { distanceKm: 0.0, elevationM: 8 },
      { distanceKm: 2.0, elevationM: 22 },
      { distanceKm: 4.0, elevationM: 31 },
      { distanceKm: 5.8, elevationM: 12 }
    ],
    conditions: {
      status: 'caution',
      lastUpdatedISO: nowISO,
      notes: 'Monsoon spray on rocks; keep distance from edges.'
    },
    photos: [
      'https://example-cdn/trails/anjuna_1.jpg',
      'https://example-cdn/trails/anjuna_2.jpg'
    ],
    reviews: { averageRating: 4.2, totalReviews: 510 },
    popularity: 69,
    viewCount: 9400,
    isActive: true,
    metadata: { surface: 'rocky' }
  },
  {
    name: 'Appian Way Segment',
    slug: slugify('Appian Way Segment'),
    description:
      'Historic walk along Via Appia Antica with cobblestones, villas, and aqueduct views.',
    difficulty: 'easy',
    lengthKm: 6.3,
    elevGainM: 50,
    tags: ['historic', 'family'],
    city: 'Rome',
    country: 'Italy',
    region: 'Lazio',
    tz: 'Europe/Rome',
    startLocation: { type: 'Point', coordinates: [12.5490, 41.8575] },
    routeGeoJSON: {
      type: 'LineString',
      coordinates: [
        [12.5490, 41.8575],
        [12.5440, 41.8600],
        [12.5372, 41.8639],
        [12.5311, 41.8678],
        [12.5250, 41.8713]
      ]
    },
    elevationProfile: [
      { distanceKm: 0.0, elevationM: 35 },
      { distanceKm: 2.0, elevationM: 45 },
      { distanceKm: 4.2, elevationM: 52 },
      { distanceKm: 6.3, elevationM: 40 }
    ],
    conditions: {
      status: 'open',
      lastUpdatedISO: nowISO,
      notes: 'Uneven cobblestones; stroller-friendly in parts.'
    },
    photos: [
      'https://example-cdn/trails/appia_1.jpg',
      'https://example-cdn/trails/appia_2.jpg'
    ],
    reviews: { averageRating: 4.7, totalReviews: 1320 },
    popularity: 91,
    viewCount: 22400,
    isActive: true,
    metadata: { surface: 'cobblestone' }
  },
  {
    name: 'Monte Mario Nature Walk',
    slug: slugify('Monte Mario Nature Walk'),
    description:
      'Panoramic loop in Monte Mario Reserve with views over Rome and the Tiber.',
    difficulty: 'moderate',
    lengthKm: 7.1,
    elevGainM: 210,
    tags: ['forest', 'viewpoints'],
    city: 'Rome',
    country: 'Italy',
    region: 'Lazio',
    tz: 'Europe/Rome',
    startLocation: { type: 'Point', coordinates: [12.4450, 41.9310] },
    routeGeoJSON: {
      type: 'LineString',
      coordinates: [
        [12.4450, 41.9310],
        [12.4409, 41.9341],
        [12.4391, 41.9380],
        [12.4427, 41.9393],
        [12.4463, 41.9358],
        [12.4450, 41.9310]
      ]
    },
    elevationProfile: [
      { distanceKm: 0.0, elevationM: 78 },
      { distanceKm: 2.2, elevationM: 150 },
      { distanceKm: 4.8, elevationM: 210 },
      { distanceKm: 7.1, elevationM: 82 }
    ],
    conditions: {
      status: 'open',
      lastUpdatedISO: nowISO,
      notes: 'Some steep sections; bring water.'
    },
    photos: [
      'https://example-cdn/trails/mario_1.jpg',
      'https://example-cdn/trails/mario_2.jpg'
    ],
    reviews: { averageRating: 4.5, totalReviews: 760 },
    popularity: 83,
    viewCount: 13900,
    isActive: true,
    metadata: { protectedArea: true }
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
    await Trail.deleteMany({});
    console.log('Cleared Trails collection');
  }

  // Upsert by slug to make the script re-runnable safely
  const ops = trails.map((t) => ({
    updateOne: {
      filter: { slug: t.slug },
      update: { $set: t },
      upsert: true
    }
  }));

  const result = await Trail.bulkWrite(ops, { ordered: false });
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
