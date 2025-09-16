// C:\flutterapp\myapp\backend\scripts\seed_hotels.js

'use strict';

/**
 * Seed Hotels collection with realistic sample data:
 * - GeoJSON Point [lng, lat] location
 * - Stars, amenities, tags, price, review aggregates, photos
 * - Rooms and simple ratePlans with ISO 8601 validity
 *
 * Usage:
 *   node scripts/seed_hotels.js --reset
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_hotels.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model path if different in the project
const Hotel = require('../models/Hotel');

const MONGODB_URI =
  process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function slugify(str) {
  return String(str || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '')
    .substring(0, 160);
}

const today = new Date();
const nextMonth = new Date(today.getTime() + 30 * 24 * 60 * 60 * 1000);

// Sample hotels
const hotels = [
  {
    name: 'Riviera Bay Resort Goa',
    slug: slugify('Riviera Bay Resort Goa'),
    brand: 'Riviera',
    description:
      'Beachside resort with a lagoon pool, spa, and direct access to the sands of Miramar.',
    stars: 4,
    amenities: [
      'pool',
      'beach_access',
      'spa',
      'wifi',
      'restaurant',
      'bar',
      'parking',
      'ac'
    ],
    tags: ['beach', 'family', 'romantic'],
    price: { amount: 4800, currency: 'INR' }, // indicative from-price per night
    address: {
      line1: 'Miramar Beach',
      city: 'Goa',
      state: 'Goa',
      country: 'India',
      postalCode: '403001'
    },
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.8035, 15.4710] }, // [lng, lat]
    photos: [
      'https://example-cdn/hotels/riviera_1.jpg',
      'https://example-cdn/hotels/riviera_2.jpg'
    ],
    reviews: { averageRating: 4.4, totalReviews: 980 },
    rooms: [
      {
        code: 'DLX-KING',
        name: 'Deluxe King',
        occupancy: { adults: 2, children: 1 },
        amenities: ['ac', 'wifi', 'tv', 'balcony'],
        areaSqm: 28,
        photos: ['https://example-cdn/hotels/riviera_room_1.jpg']
      },
      {
        code: 'FAM-SUITE',
        name: 'Family Suite',
        occupancy: { adults: 3, children: 2 },
        amenities: ['ac', 'wifi', 'tv', 'sofabed'],
        areaSqm: 45,
        photos: ['https://example-cdn/hotels/riviera_room_2.jpg']
      }
    ],
    ratePlans: [
      {
        id: 'BB-FLEX',
        name: 'Bed & Breakfast – Flexible',
        roomCodes: ['DLX-KING', 'FAM-SUITE'],
        currency: 'INR',
        pricePerNight: 5500,
        inclusions: ['breakfast'],
        cancellation: 'Free cancel until 24h before check-in',
        validFromISO: today.toISOString(),
        validToISO: nextMonth.toISOString()
      },
      {
        id: 'RO-NR',
        name: 'Room Only – Non-Refundable',
        roomCodes: ['DLX-KING'],
        currency: 'INR',
        pricePerNight: 4800,
        inclusions: [],
        cancellation: 'Non-refundable',
        validFromISO: today.toISOString(),
        validToISO: nextMonth.toISOString()
      }
    ],
    policies: {
      checkIn: '14:00',
      checkOut: '11:00',
      smoking: 'non_smoking'
    },
    popularity: 88,
    viewCount: 18950,
    isActive: true,
    metadata: { beachDistanceM: 50 }
  },
  {
    name: 'Fontana Boutique Stay',
    slug: slugify('Fontana Boutique Stay'),
    brand: 'Indie',
    description:
      'Charming boutique hotel in Fontainhas with colorful Portuguese-era decor and cozy rooms.',
    stars: 3,
    amenities: ['wifi', 'ac', 'restaurant', 'parking'],
    tags: ['heritage', 'boutique', 'photography'],
    price: { amount: 3200, currency: 'INR' },
    address: {
      line1: 'Fontainhas',
      city: 'Goa',
      state: 'Goa',
      country: 'India',
      postalCode: '403001'
    },
    city: 'Goa',
    country: 'India',
    tz: 'Asia/Kolkata',
    location: { type: 'Point', coordinates: [73.8295, 15.4981] },
    photos: [
      'https://example-cdn/hotels/fontana_1.jpg',
      'https://example-cdn/hotels/fontana_2.jpg'
    ],
    reviews: { averageRating: 4.6, totalReviews: 420 },
    rooms: [
      {
        code: 'STD-QUEEN',
        name: 'Standard Queen',
        occupancy: { adults: 2, children: 0 },
        amenities: ['ac', 'wifi', 'tv'],
        areaSqm: 20,
        photos: ['https://example-cdn/hotels/fontana_room_1.jpg']
      }
    ],
    ratePlans: [
      {
        id: 'CP-FLEX',
        name: 'Continental Plan – Flexible',
        roomCodes: ['STD-QUEEN'],
        currency: 'INR',
        pricePerNight: 3600,
        inclusions: ['breakfast'],
        cancellation: 'Free cancel until 24h before check-in',
        validFromISO: today.toISOString(),
        validToISO: nextMonth.toISOString()
      }
    ],
    policies: { checkIn: '13:00', checkOut: '11:00' },
    popularity: 76,
    viewCount: 8650,
    isActive: true,
    metadata: { heritageZone: true }
  },
  {
    name: 'Roma Centro Grand',
    slug: slugify('Roma Centro Grand'),
    brand: 'Grand Italia',
    description:
      'Elegant city hotel near Roma Termini with premium rooms, rooftop bar, and quick metro access.',
    stars: 5,
    amenities: [
      'wifi',
      'ac',
      'restaurant',
      'bar',
      'spa',
      'gym',
      'concierge',
      'parking'
    ],
    tags: ['city_center', 'luxury'],
    price: { amount: 180, currency: 'EUR' },
    address: {
      line1: 'Via Cavour',
      city: 'Rome',
      state: 'Lazio',
      country: 'Italy',
      postalCode: '00184'
    },
    city: 'Rome',
    country: 'Italy',
    tz: 'Europe/Rome',
    location: { type: 'Point', coordinates: [12.5018, 41.9022] },
    photos: [
      'https://example-cdn/hotels/romacentro_1.jpg',
      'https://example-cdn/hotels/romacentro_2.jpg'
    ],
    reviews: { averageRating: 4.7, totalReviews: 2130 },
    rooms: [
      {
        code: 'SUP-KING',
        name: 'Superior King',
        occupancy: { adults: 2, children: 1 },
        amenities: ['ac', 'wifi', 'tv', 'espresso_machine'],
        areaSqm: 30,
        photos: ['https://example-cdn/hotels/romacentro_room_1.jpg']
      },
      {
        code: 'JNR-SUITE',
        name: 'Junior Suite',
        occupancy: { adults: 3, children: 1 },
        amenities: ['ac', 'wifi', 'tv', 'sofabed'],
        areaSqm: 45,
        photos: ['https://example-cdn/hotels/romacentro_room_2.jpg']
      }
    ],
    ratePlans: [
      {
        id: 'BB-FLEX-EU',
        name: 'Bed & Breakfast – Flexible',
        roomCodes: ['SUP-KING', 'JNR-SUITE'],
        currency: 'EUR',
        pricePerNight: 210,
        inclusions: ['breakfast'],
        cancellation: 'Free cancel until 48h before check-in',
        validFromISO: today.toISOString(),
        validToISO: nextMonth.toISOString()
      },
      {
        id: 'RO-NR-EU',
        name: 'Room Only – NR',
        roomCodes: ['SUP-KING'],
        currency: 'EUR',
        pricePerNight: 180,
        inclusions: [],
        cancellation: 'Non-refundable',
        validFromISO: today.toISOString(),
        validToISO: nextMonth.toISOString()
      }
    ],
    policies: { checkIn: '15:00', checkOut: '12:00' },
    popularity: 93,
    viewCount: 32900,
    isActive: true,
    metadata: { metroDistanceM: 300 }
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
    await Hotel.deleteMany({});
    console.log('Cleared Hotels collection');
  }

  // Upsert by slug to make the script re-runnable safely
  const ops = hotels.map((h) => ({
    updateOne: {
      filter: { slug: h.slug },
      update: { $set: h },
      upsert: true
    }
  }));

  const result = await Hotel.bulkWrite(ops, { ordered: false });
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
