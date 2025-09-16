// C:\flutterapp\myapp\backend\scripts\seed_activities.js

'use strict';

/**
 * Seed Activities collection with realistic sample data:
 * - GeoJSON Point [lng, lat] for location
 * - ISO 8601 strings for availability slots (startISO/endISO)
 * - Fields aligned with frontend flows: tags, price, reviews aggregate, photos, popularity, etc.
 *
 * Usage:
 *   node scripts/seed_activities.js --reset   # clears Activities before seeding
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_activities.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model path if different in the project
const Activity = require('../models/Activity');

// Connection
const MONGODB_URI =
  process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function slugify(str) {
  return String(str || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '')
    .substring(0, 160);
}

function iso(dateStr) {
  // Helper passthrough to make intent explicit in seed items
  return dateStr;
}

const now = new Date();
const nextMonth = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

// Sample activities
const activities = [
  {
    name: 'Old Goa Heritage Walk',
    slug: slugify('Old Goa Heritage Walk'),
    description:
      'A guided walking tour through Old Goa’s UNESCO heritage sites and hidden lanes.',
    type: 'tour',
    categories: ['culture', 'history'],
    tags: ['walking', 'architecture', 'heritage', 'photography'],
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: {
      type: 'Point',
      coordinates: [73.9096, 15.5007] // [lng, lat]
    },
    durationMin: 120,
    capacity: 20,
    language: ['en'],
    price: { amount: 799, currency: 'INR' },
    features: ['guide', 'small_group'],
    reviews: { averageRating: 4.6, totalReviews: 128 },
    photos: [
      'https://example-cdn/img/goa_heritage_1.jpg',
      'https://example-cdn/img/goa_heritage_2.jpg'
    ],
    availability: {
      slots: [
        { startISO: iso('2025-09-20T08:00:00+05:30'), endISO: iso('2025-09-20T10:00:00+05:30'), capacity: 12 },
        { startISO: iso('2025-09-21T16:00:00+05:30'), endISO: iso('2025-09-21T18:00:00+05:30'), capacity: 10 }
      ],
      validFrom: now,
      validTo: nextMonth
    },
    popularity: 92,
    viewCount: 2180,
    isActive: true,
    metadata: { provider: 'demo', difficulty: 'easy' }
  },
  {
    name: 'Mandovi Sunset Cruise',
    slug: slugify('Mandovi Sunset Cruise'),
    description:
      'Evening cruise on the Mandovi river with live music and local snacks.',
    type: 'experience',
    categories: ['leisure'],
    tags: ['boat', 'sunset', 'music'],
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: {
      type: 'Point',
      coordinates: [73.8278, 15.4989]
    },
    durationMin: 90,
    capacity: 80,
    language: ['en', 'hi'],
    price: { amount: 1299, currency: 'INR' },
    features: ['live_music', 'snacks'],
    reviews: { averageRating: 4.3, totalReviews: 412 },
    photos: [
      'https://example-cdn/img/mandovi_1.jpg',
      'https://example-cdn/img/mandovi_2.jpg'
    ],
    availability: {
      slots: [
        { startISO: iso('2025-09-20T18:00:00+05:30'), endISO: iso('2025-09-20T19:30:00+05:30'), capacity: 60 },
        { startISO: iso('2025-09-21T18:00:00+05:30'), endISO: iso('2025-09-21T19:30:00+05:30'), capacity: 60 }
      ],
      validFrom: now,
      validTo: nextMonth
    },
    popularity: 88,
    viewCount: 5340,
    isActive: true,
    metadata: { provider: 'demo', familyFriendly: true }
  },
  {
    name: 'Fontainhas Art District Photo Walk',
    slug: slugify('Fontainhas Art District Photo Walk'),
    description:
      'Explore the vibrant lanes of Fontainhas and capture colorful Portuguese-era homes.',
    type: 'tour',
    categories: ['culture', 'photography'],
    tags: ['walking', 'art', 'colors'],
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: {
      type: 'Point',
      coordinates: [73.8295, 15.4981]
    },
    durationMin: 150,
    capacity: 15,
    language: ['en'],
    price: { amount: 999, currency: 'INR' },
    features: ['guide', 'photo_tips'],
    reviews: { averageRating: 4.8, totalReviews: 89 },
    photos: [
      'https://example-cdn/img/fontainhas_1.jpg',
      'https://example-cdn/img/fontainhas_2.jpg'
    ],
    availability: {
      slots: [
        { startISO: iso('2025-09-20T07:00:00+05:30'), endISO: iso('2025-09-20T09:30:00+05:30'), capacity: 12 },
        { startISO: iso('2025-09-21T07:00:00+05:30'), endISO: iso('2025-09-21T09:30:00+05:30'), capacity: 12 }
      ],
      validFrom: now,
      validTo: nextMonth
    },
    popularity: 75,
    viewCount: 1840,
    isActive: true,
    metadata: { provider: 'demo', difficulty: 'easy' }
  },
  {
    name: 'Vatican Museums Early Access',
    slug: slugify('Vatican Museums Early Access'),
    description:
      'Skip-the-line early access tour through the Vatican Museums and Sistine Chapel.',
    type: 'tour',
    categories: ['culture', 'museum'],
    tags: ['skip_the_line', 'guided'],
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    location: {
      type: 'Point',
      coordinates: [12.4534, 41.9065]
    },
    durationMin: 180,
    capacity: 20,
    language: ['en', 'it'],
    price: { amount: 69, currency: 'EUR' },
    features: ['early_access', 'guide'],
    reviews: { averageRating: 4.7, totalReviews: 1520 },
    photos: [
      'https://example-cdn/img/vatican_1.jpg',
      'https://example-cdn/img/vatican_2.jpg'
    ],
    availability: {
      slots: [
        { startISO: iso('2025-09-20T07:30:00+02:00'), endISO: iso('2025-09-20T10:30:00+02:00'), capacity: 18 },
        { startISO: iso('2025-09-21T07:30:00+02:00'), endISO: iso('2025-09-21T10:30:00+02:00'), capacity: 18 }
      ],
      validFrom: now,
      validTo: nextMonth
    },
    popularity: 97,
    viewCount: 25410,
    isActive: true,
    metadata: { provider: 'demo', accessibility: ['wheelchair'] }
  },
  {
    name: 'Colosseum Underground and Arena',
    slug: slugify('Colosseum Underground and Arena'),
    description:
      'Guided access to the underground tunnels and arena floor of the Colosseum.',
    type: 'tour',
    categories: ['culture', 'history'],
    tags: ['exclusive', 'guided'],
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    location: {
      type: 'Point',
      coordinates: [12.4922, 41.8902]
    },
    durationMin: 150,
    capacity: 25,
    language: ['en'],
    price: { amount: 79, currency: 'EUR' },
    features: ['arena_floor', 'underground'],
    reviews: { averageRating: 4.9, totalReviews: 980 },
    photos: [
      'https://example-cdn/img/colosseum_1.jpg',
      'https://example-cdn/img/colosseum_2.jpg'
    ],
    availability: {
      slots: [
        { startISO: iso('2025-09-20T09:00:00+02:00'), endISO: iso('2025-09-20T11:30:00+02:00'), capacity: 22 },
        { startISO: iso('2025-09-21T13:00:00+02:00'), endISO: iso('2025-09-21T15:30:00+02:00'), capacity: 22 }
      ],
      validFrom: now,
      validTo: nextMonth
    },
    popularity: 95,
    viewCount: 22150,
    isActive: true,
    metadata: { provider: 'demo' }
  }
];

async function connect() {
  // Keep options minimal; prefer env-driven URI for deploys
  await mongoose.connect(MONGODB_URI, { family: 4 });
  mongoose.connection.on('error', (err) => {
    console.error('Mongo connection error:', err);
  });
  console.log('Connected to MongoDB:', mongoose.connection.name);
}

async function seed({ reset = false } = {}) {
  if (reset) {
    await Activity.deleteMany({});
    console.log('Cleared Activities collection');
  }

  // Ensure slugs present when missing
  for (const a of activities) {
    if (!a.slug && a.name) a.slug = slugify(a.name);
  }

  const inserted = await Activity.insertMany(activities, { ordered: false });
  console.log(`Inserted ${inserted.length} activities`);
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
