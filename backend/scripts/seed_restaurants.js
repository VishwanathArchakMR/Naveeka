// C:\flutterapp\myapp\backend\scripts\seed_restaurants.js

'use strict';

/**
 * Seed Restaurants collection with realistic sample data:
 * - GeoJSON Point [lng, lat] for location
 * - Cuisines, dietary options, features, price bucket
 * - Menus (sections/items/prices) and ISO 8601 reservation slots
 * - Reviews aggregate, photos, popularity/view counts
 *
 * Usage:
 *   node scripts/seed_restaurants.js --reset
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_restaurants.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model path if different in the project
const Restaurant = require('../models/Restaurant');

const MONGODB_URI =
  process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function slugify(str) {
  return String(str || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '')
    .substring(0, 160);
}

function iso(s) {
  return s; // helper to annotate ISO strings in seed data
}

const now = new Date();
const nextMonth = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

// Sample restaurants
const restaurants = [
  {
    name: 'Riverside Seafood Shack',
    slug: slugify('Riverside Seafood Shack'),
    description:
      'Casual beachfront shack famous for Goan seafood thalis and sunset views.',
    cuisines: ['Goan', 'Seafood'],
    dietary: ['vegetarian_options'],
    features: ['outdoor_seating', 'live_music', 'reservations'],
    priceBucket: '₹₹',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    address: {
      line1: 'Miramar Beach',
      city: 'Goa',
      state: 'Goa',
      country: 'India',
      postalCode: '403001'
    },
    location: { type: 'Point', coordinates: [73.8035, 15.4710] }, // [lng, lat]
    photos: [
      'https://example-cdn/restaurants/riverside_1.jpg',
      'https://example-cdn/restaurants/riverside_2.jpg'
    ],
    reviews: { averageRating: 4.5, totalReviews: 1240 },
    menus: [
      {
        section: 'Starters',
        items: [
          { name: 'Prawn Rava Fry', price: { amount: 420, currency: 'INR' }, tags: ['spicy'] },
          { name: 'Goan Sausage Pao', price: { amount: 220, currency: 'INR' } }
        ]
      },
      {
        section: 'Mains',
        items: [
          { name: 'Fish Curry Rice', price: { amount: 360, currency: 'INR' }, tags: ['signature'] },
          { name: 'Seafood Thali', price: { amount: 520, currency: 'INR' } }
        ]
      },
      {
        section: 'Beverages',
        items: [{ name: 'Fresh Lime Soda', price: { amount: 90, currency: 'INR' } }]
      }
    ],
    availability: {
      slots: [
        { startISO: iso('2025-09-21T19:00:00+05:30'), endISO: iso('2025-09-21T21:00:00+05:30'), capacity: 24 },
        { startISO: iso('2025-09-22T13:00:00+05:30'), endISO: iso('2025-09-22T15:00:00+05:30'), capacity: 18 }
      ],
      validFrom: now,
      validTo: nextMonth
    },
    popularity: 87,
    viewCount: 15480,
    isActive: true,
    metadata: { parking: 'limited' }
  },
  {
    name: 'Fontainhas Café & Bistro',
    slug: slugify('Fontainhas Café & Bistro'),
    description:
      'Charming bistro in the art district serving European plates and Goan-inspired specials.',
    cuisines: ['European', 'Goan'],
    dietary: ['vegetarian_options', 'gluten_free_options'],
    features: ['reservations', 'indoor_seating', 'wifi'],
    priceBucket: '₹₹',
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    address: {
      line1: 'Fontainhas',
      city: 'Goa',
      state: 'Goa',
      country: 'India',
      postalCode: '403001'
    },
    location: { type: 'Point', coordinates: [73.8295, 15.4981] },
    photos: [
      'https://example-cdn/restaurants/fontainhas_1.jpg',
      'https://example-cdn/restaurants/fontainhas_2.jpg'
    ],
    reviews: { averageRating: 4.6, totalReviews: 640 },
    menus: [
      {
        section: 'Brunch',
        items: [
          { name: 'Shakshuka', price: { amount: 320, currency: 'INR' } },
          { name: 'Croque Madame', price: { amount: 380, currency: 'INR' } }
        ]
      },
      {
        section: 'Coffee & Tea',
        items: [
          { name: 'Cappuccino', price: { amount: 180, currency: 'INR' } },
          { name: 'Masala Chai', price: { amount: 120, currency: 'INR' } }
        ]
      }
    ],
    availability: {
      slots: [
        { startISO: iso('2025-09-21T09:00:00+05:30'), endISO: iso('2025-09-21T11:00:00+05:30'), capacity: 20 },
        { startISO: iso('2025-09-22T19:30:00+05:30'), endISO: iso('2025-09-22T21:00:00+05:30'), capacity: 16 }
      ],
      validFrom: now,
      validTo: nextMonth
    },
    popularity: 74,
    viewCount: 7820,
    isActive: true,
    metadata: { neighborhood: 'Fontainhas' }
  },
  {
    name: 'Trastevere Osteria',
    slug: slugify('Trastevere Osteria'),
    description:
      'Cozy Roman osteria offering classic pasta, seasonal produce, and a fine wine list.',
    cuisines: ['Italian', 'Roman'],
    dietary: ['vegetarian_options'],
    features: ['reservations', 'outdoor_seating', 'wine'],
    priceBucket: '€€',
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    address: {
      line1: 'Via della Scala',
      city: 'Rome',
      state: 'Lazio',
      country: 'Italy',
      postalCode: '00153'
    },
    location: { type: 'Point', coordinates: [12.4660, 41.8890] },
    photos: [
      'https://example-cdn/restaurants/trastevere_1.jpg',
      'https://example-cdn/restaurants/trastevere_2.jpg'
    ],
    reviews: { averageRating: 4.7, totalReviews: 2010 },
    menus: [
      {
        section: 'Antipasti',
        items: [
          { name: 'Bruschetta al Pomodoro', price: { amount: 6, currency: 'EUR' } },
          { name: 'Carciofi alla Romana', price: { amount: 10, currency: 'EUR' } }
        ]
      },
      {
        section: 'Primi',
        items: [
          { name: 'Cacio e Pepe', price: { amount: 12, currency: 'EUR' }, tags: ['signature'] },
          { name: 'Amatriciana', price: { amount: 13, currency: 'EUR' } }
        ]
      },
      {
        section: 'Secondi',
        items: [
          { name: 'Saltimbocca alla Romana', price: { amount: 18, currency: 'EUR' } }
        ]
      }
    ],
    availability: {
      slots: [
        { startISO: iso('2025-09-21T19:30:00+02:00'), endISO: iso('2025-09-21T21:30:00+02:00'), capacity: 28 },
        { startISO: iso('2025-09-22T12:30:00+02:00'), endISO: iso('2025-09-22T14:30:00+02:00'), capacity: 24 }
      ],
      validFrom: now,
      validTo: nextMonth
    },
    popularity: 92,
    viewCount: 32450,
    isActive: true,
    metadata: { neighborhood: 'Trastevere' }
  },
  {
    name: 'Pizzeria al Taglio Centro',
    slug: slugify('Pizzeria al Taglio Centro'),
    description:
      'Crispy Roman-style pizza by the slice with seasonal toppings and quick service.',
    cuisines: ['Italian', 'Pizza'],
    dietary: ['vegetarian_options'],
    features: ['takeaway', 'no_reservations'],
    priceBucket: '€',
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    address: {
      line1: 'Via Nazionale',
      city: 'Rome',
      state: 'Lazio',
      country: 'Italy',
      postalCode: '00184'
    },
    location: { type: 'Point', coordinates: [12.5018, 41.9022] },
    photos: [
      'https://example-cdn/restaurants/pizzeria_1.jpg',
      'https://example-cdn/restaurants/pizzeria_2.jpg'
    ],
    reviews: { averageRating: 4.4, totalReviews: 980 },
    menus: [
      {
        section: 'By the Slice',
        items: [
          { name: 'Margherita', price: { amount: 3.5, currency: 'EUR' } },
          { name: 'Diavola', price: { amount: 4.0, currency: 'EUR' } }
        ]
      },
      {
        section: 'Drinks',
        items: [
          { name: 'Acqua Frizzante', price: { amount: 1.5, currency: 'EUR' } },
          { name: 'Birra Artigianale', price: { amount: 5.0, currency: 'EUR' } }
        ]
      }
    ],
    availability: {
      slots: [
        { startISO: iso('2025-09-21T12:00:00+02:00'), endISO: iso('2025-09-21T15:00:00+02:00'), capacity: 40 },
        { startISO: iso('2025-09-21T18:00:00+02:00'), endISO: iso('2025-09-21T22:00:00+02:00'), capacity: 60 }
      ],
      validFrom: now,
      validTo: nextMonth
    },
    popularity: 79,
    viewCount: 15700,
    isActive: true,
    metadata: { style: 'pizza_al_taglio' }
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
    await Restaurant.deleteMany({});
    console.log('Cleared Restaurants collection');
  }

  // Upsert by slug to make the script re-runnable safely
  const ops = restaurants.map((r) => ({
    updateOne: {
      filter: { slug: r.slug },
      update: { $set: r },
      upsert: true
    }
  }));

  const result = await Restaurant.bulkWrite(ops, { ordered: false });
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
