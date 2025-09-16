// C:\flutterapp\myapp\backend\scripts\seed_planning.js

'use strict';

/**
 * Seeds planning data:
 * - Creates/updates a Trip Group with roles, dates, settings (destination, currency, tz)
 * - Adds itinerary items with ISO 8601 times and GeoJSON Point locations
 * - Adds budget expenses with simple splits, checklist items, and documents
 * - Attempts to cross-link seeded Activities/Hotels by slug if available
 *
 * Usage:
 *   node scripts/seed_planning.js --owner=<userId> --members=<id2,id3,...> --reset
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_planning.js --owner=<id> --members=<ids>
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Models (adjust paths if different)
const TripGroup = require('../models/TripGroup');
const Activity = require('../models/Activity'); // optional cross-links
const Hotel = require('../models/Hotel');       // optional cross-links

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

// ---------- Helpers ----------

function parseArg(key) {
  const pref = `--${key}=`;
  const hit = process.argv.find((a) => a.startsWith(pref));
  return hit ? hit.slice(pref.length) : null;
}

function parseIdsCSV(s) {
  if (!s) return [];
  return s.split(',').map((x) => x.trim()).filter(Boolean).map((x) => new mongoose.Types.ObjectId(x));
}

function iso(d) {
  return new Date(d).toISOString(); // ISO 8601
}

function slugify(str) {
  return String(str || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '')
    .substring(0, 160);
}

// optional lookup for seeded entities
async function getActivityIdBySlug(slug) {
  try {
    const a = await Activity.findOne({ slug }).select('_id').lean();
    return a?._id || undefined;
  } catch {
    return undefined;
  }
}

async function getHotelIdBySlug(slug) {
  try {
    const h = await Hotel.findOne({ slug }).select('_id').lean();
    return h?._id || undefined;
  } catch {
    return undefined;
  }
}

async function connect() {
  await mongoose.connect(MONGODB_URI, { family: 4 });
  mongoose.connection.on('error', (err) => {
    console.error('Mongo connection error:', err);
  });
  console.log('Connected to MongoDB:', mongoose.connection.name);
}

// ---------- Seed Data Builder ----------

async function buildTripGroup(ownerId, memberIds) {
  const name = 'Goa Long Weekend';
  const slug = slugify(name);
  const seedKey = 'seed:trip:goa-long-weekend';

  // Dates
  const start = new Date('2025-09-21T00:00:00+05:30');
  const end = new Date('2025-09-24T00:00:00+05:30');

  // Try linking to previously seeded activities/hotel
  const actOldGoa = await getActivityIdBySlug('old-goa-heritage-walk');
  const actSunset = await getActivityIdBySlug('mandovi-sunset-cruise');
  const actPhoto = await getActivityIdBySlug('fontainhas-art-district-photo-walk');
  const hotelRiviera = await getHotelIdBySlug('riviera-bay-resort-goa');

  // Itinerary with GeoJSON Points [lng, lat]
  const itinerary = [
    // Day 0 (arrival day)
    {
      dayOffset: 0,
      seq: 0,
      title: 'Arrive in Goa + Check-in',
      type: 'transport',
      entityType: 'hotel',
      entityId: hotelRiviera,
      startISO: iso('2025-09-21T11:30:00+05:30'),
      endISO: iso('2025-09-21T13:00:00+05:30'),
      durationMin: 90,
      location: { type: 'Point', coordinates: [73.8035, 15.4710] },
      address: { city: 'Goa', country: 'India' },
      notes: 'Airport transfer and hotel check-in',
      tags: ['arrival', 'checkin'],
      photos: [],
      meta: { seed: true }
    },
    {
      dayOffset: 0,
      seq: 1,
      title: 'Mandovi Sunset Cruise',
      type: 'activity',
      entityType: 'activity',
      entityId: actSunset,
      startISO: iso('2025-09-21T18:00:00+05:30'),
      endISO: iso('2025-09-21T19:30:00+05:30'),
      durationMin: 90,
      location: { type: 'Point', coordinates: [73.8278, 15.4989] },
      address: { city: 'Goa', country: 'India' },
      tags: ['sunset', 'boat'],
      meta: { seed: true }
    },
    // Day 1
    {
      dayOffset: 1,
      seq: 0,
      title: 'Old Goa Heritage Walk',
      type: 'activity',
      entityType: 'activity',
      entityId: actOldGoa,
      startISO: iso('2025-09-22T08:00:00+05:30'),
      endISO: iso('2025-09-22T10:00:00+05:30'),
      durationMin: 120,
      location: { type: 'Point', coordinates: [73.9096, 15.5007] },
      address: { city: 'Goa', country: 'India' },
      tags: ['walking', 'history'],
      meta: { seed: true }
    },
    {
      dayOffset: 1,
      seq: 1,
      title: 'Beach Time at Miramar',
      type: 'activity',
      startISO: iso('2025-09-22T16:00:00+05:30'),
      endISO: iso('2025-09-22T18:00:00+05:30'),
      durationMin: 120,
      location: { type: 'Point', coordinates: [73.8035, 15.4710] },
      address: { city: 'Goa', country: 'India' },
      tags: ['beach'],
      meta: { seed: true }
    },
    // Day 2
    {
      dayOffset: 2,
      seq: 0,
      title: 'Fontainhas Photo Walk',
      type: 'activity',
      entityType: 'activity',
      entityId: actPhoto,
      startISO: iso('2025-09-23T07:00:00+05:30'),
      endISO: iso('2025-09-23T09:30:00+05:30'),
      durationMin: 150,
      location: { type: 'Point', coordinates: [73.8295, 15.4981] },
      address: { city: 'Goa', country: 'India' },
      tags: ['photography'],
      meta: { seed: true }
    },
    {
      dayOffset: 2,
      seq: 1,
      title: 'Dinner by the Beach',
      type: 'food',
      startISO: iso('2025-09-23T20:00:00+05:30'),
      endISO: iso('2025-09-23T21:30:00+05:30'),
      durationMin: 90,
      location: { type: 'Point', coordinates: [73.7700, 15.4900] },
      address: { city: 'Goa', country: 'India' },
      tags: ['seafood'],
      meta: { seed: true }
    },
    // Day 3 (checkout)
    {
      dayOffset: 3,
      seq: 0,
      title: 'Check-out and Depart',
      type: 'transport',
      startISO: iso('2025-09-24T10:00:00+05:30'),
      endISO: iso('2025-09-24T12:00:00+05:30'),
      durationMin: 120,
      location: { type: 'Point', coordinates: [73.8390, 15.7230] }, // GOX approx
      address: { city: 'Goa', country: 'India' },
      tags: ['departure', 'checkout'],
      meta: { seed: true }
    }
  ];

  // Expenses
  const expenses = [
    {
      title: 'Hotel (3 nights)',
      amount: 16500,
      currency: 'INR',
      category: 'stay',
      paidBy: ownerId,
      split: { type: 'equal', shares: [] },
      occurredAtISO: iso('2025-09-21T13:00:00+05:30'),
      notes: 'Riviera Bay Resort – BB Flex',
      createdBy: ownerId,
      updatedBy: ownerId
    },
    {
      title: 'Sunset cruise tickets',
      amount: 2598,
      currency: 'INR',
      category: 'activity',
      paidBy: memberIds || ownerId,
      split: { type: 'equal', shares: [] },
      occurredAtISO: iso('2025-09-21T17:45:00+05:30'),
      notes: '2 adults',
      createdBy: memberIds || ownerId,
      updatedBy: memberIds || ownerId
    },
    {
      title: 'Dinner (Seafood)',
      amount: 1800,
      currency: 'INR',
      category: 'food',
      paidBy: memberIds || ownerId,
      split: { type: 'equal', shares: [] },
      occurredAtISO: iso('2025-09-23T22:00:00+05:30'),
      notes: 'Beach shack',
      createdBy: memberIds || ownerId,
      updatedBy: memberIds || ownerId
    }
  ];

  // Checklist
  const checklist = [
    { title: 'Add flight details', done: false, assignees: [ownerId] },
    { title: 'Confirm hotel booking', done: true, assignees: [ownerId] },
    { title: 'Buy sunscreen', done: false, assignees: memberIds.slice(0, 1) }
  ];

  // Documents (metadata only, upload handled elsewhere)
  const documents = [
    {
      key: 'itinerary/goa-long-weekend.pdf',
      name: 'Itinerary - Goa Long Weekend.pdf',
      mime: 'application/pdf',
      size: 102400,
      url: 'https://example-cdn/docs/goa_long_weekend.pdf'
    }
  ];

  return {
    seedKey,
    name,
    slug,
    cover: 'https://example-cdn/covers/goa_weekend.jpg',
    ownerId,
    members: memberIds,
    roles: Object.fromEntries([ownerId, ...memberIds].map((id, idx) => [id.toString(), idx === 0 ? 'admin' : 'member'])),
    startDate: start,
    endDate: end,
    settings: { destination: 'Goa, India', currency: 'INR', tz: 'Asia/Kolkata' },
    itinerary,
    budget: { baseCurrency: 'INR', expenses },
    checklist,
    documents,
    likesCount: 0,
    viewCount: 0,
    popularity: 0,
    isActive: true,
    metadata: { seedKey }
  };
}

// ---------- Main Seed Logic ----------

async function seed({ reset = false, ownerId, memberIds }) {
  if (!ownerId) throw new Error('Missing required --owner=<userId>');
  const groupData = await buildTripGroup(ownerId, memberIds);

  if (reset) {
    await TripGroup.deleteMany({ 'metadata.seedKey': groupData.metadata.seedKey });
    console.log('Cleared previously seeded trip groups with the same seedKey');
  }

  const updated = await TripGroup.findOneAndUpdate(
    { 'metadata.seedKey': groupData.metadata.seedKey, ownerId: ownerId },
    { $set: groupData },
    { new: true, upsert: true }
  );

  console.log(`Seeded Trip Group: ${updated.name} (${updated._id})`);
}

async function main() {
  const ownerStr = parseArg('owner');
  const membersStr = parseArg('members');
  const reset = process.argv.includes('--reset');

  const ownerId = ownerStr ? new mongoose.Types.ObjectId(ownerStr) : null;
  const memberIds = parseIdsCSV(membersStr);

  try {
    await connect();
    await seed({ reset, ownerId, memberIds });
  } catch (err) {
    console.error('Seeding error:', err.message || err);
    process.exitCode = 1;
  } finally {
    await mongoose.connection.close();
    console.log('MongoDB connection closed');
  }
}

if (require.main === module) {
  main();
}
