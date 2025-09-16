// C:\flutterapp\myapp\backend\scripts\seed_locations_master.js

'use strict';

/**
 * Seed Locations Master with countries, regions, and cities:
 * - Countries: ISO 3166 codes, currency, tz, centroid (Point), bbox (Polygon)
 * - Regions: parentCountry, centroid, bbox, tz
 * - Cities: parentRegion/parentCountry, centroid, tz
 *
 * Usage:
 *   node scripts/seed_locations_master.js --reset
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_locations_master.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model path if different in the project
const LocationMaster = require('../models/LocationMaster'); // expects a model with fields used below

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function slugify(str) {
  return String(str || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '')
    .substring(0, 160);
}

// Helper to build a rectangular bbox polygon from [minLng, minLat, maxLng, maxLat]
function bboxPolygon([minLng, minLat, maxLng, maxLat]) {
  return {
    type: 'Polygon',
    coordinates: [[
      [minLng, maxLat],
      [maxLng, maxLat],
      [maxLng, minLat],
      [minLng, minLat],
      [minLng, maxLat]
    ]]
  };
}

async function connect() {
  await mongoose.connect(MONGODB_URI, { family: 4 });
  mongoose.connection.on('error', (err) => {
    console.error('Mongo connection error:', err);
  });
  console.log('Connected to MongoDB:', mongoose.connection.name);
}

async function seed({ reset = false } = {}) {
  if (reset) {
    await LocationMaster.deleteMany({});
    console.log('Cleared LocationMaster collection');
  }

  // 1) Countries (ISO 3166-1 codes, IANA tz exemplar)
  const countries = [
    {
      type: 'country',
      name: 'India',
      slug: slugify('India'),
      iso2: 'IN',
      iso3: 'IND',
      currency: 'INR',
      tz: 'Asia/Kolkata',
      centroid: { type: 'Point', coordinates: [78.9629, 20.5937] }, // [lng, lat]
      bbox: bboxPolygon([68.1766, 6.5546, 97.4026, 35.6745]),
      aliases: ['Bharat'],
      popularity: 99,
      isActive: true,
      metadata: { dialingCode: '+91' }
    },
    {
      type: 'country',
      name: 'Italy',
      slug: slugify('Italy'),
      iso2: 'IT',
      iso3: 'ITA',
      currency: 'EUR',
      tz: 'Europe/Rome',
      centroid: { type: 'Point', coordinates: [12.5674, 41.8719] },
      bbox: bboxPolygon([6.6273, 35.2889, 18.7845, 47.0920]),
      aliases: ['Italia'],
      popularity: 95,
      isActive: true,
      metadata: { dialingCode: '+39' }
    }
  ];

  // Upsert countries by iso2
  const countryOps = countries.map((c) => ({
    updateOne: { filter: { type: 'country', iso2: c.iso2 }, update: { $set: c }, upsert: true }
  }));
  await LocationMaster.bulkWrite(countryOps, { ordered: false });

  // Fetch country ids
  const inCountry = await LocationMaster.findOne({ type: 'country', iso2: 'IN' }).select('_id slug').lean();
  const itCountry = await LocationMaster.findOne({ type: 'country', iso2: 'IT' }).select('_id slug').lean();

  // 2) Regions (approximate bboxes)
  const regions = [
    {
      type: 'region',
      name: 'Goa',
      slug: slugify('Goa'),
      countryId: inCountry?._id,
      countrySlug: inCountry?.slug,
      tz: 'Asia/Kolkata',
      centroid: { type: 'Point', coordinates: [73.94, 15.40] },
      bbox: bboxPolygon([73.65, 14.90, 74.35, 15.80]),
      aliases: [],
      popularity: 88,
      isActive: true,
      metadata: { stateCode: 'GA' }
    },
    {
      type: 'region',
      name: 'Lazio',
      slug: slugify('Lazio'),
      countryId: itCountry?._id,
      countrySlug: itCountry?.slug,
      tz: 'Europe/Rome',
      centroid: { type: 'Point', coordinates: [12.8, 41.9] },
      bbox: bboxPolygon([11.40, 40.80, 14.00, 42.80]),
      aliases: [],
      popularity: 80,
      isActive: true,
      metadata: { nutsCode: 'ITI4' }
    }
  ];

  const regionOps = regions.map((r) => ({
    updateOne: { filter: { type: 'region', slug: r.slug, countrySlug: r.countrySlug }, update: { $set: r }, upsert: true }
  }));
  await LocationMaster.bulkWrite(regionOps, { ordered: false });

  // Fetch region ids
  const goaRegion = await LocationMaster.findOne({ type: 'region', slug: 'goa' }).select('_id slug').lean();
  const lazioRegion = await LocationMaster.findOne({ type: 'region', slug: 'lazio' }).select('_id slug').lean();

  // 3) Cities (centroids aligned with seeded entities)
  const cities = [
    // India / Goa
    {
      type: 'city',
      name: 'Panaji',
      slug: slugify('Panaji'),
      countryId: inCountry?._id,
      countrySlug: inCountry?.slug,
      regionId: goaRegion?._id,
      regionSlug: goaRegion?.slug,
      tz: 'Asia/Kolkata',
      centroid: { type: 'Point', coordinates: [73.8278, 15.4989] },
      aliases: ['Panjim'],
      popularity: 78,
      isActive: true,
      metadata: { }
    },
    {
      type: 'city',
      name: 'Mapusa',
      slug: slugify('Mapusa'),
      countryId: inCountry?._id,
      countrySlug: inCountry?.slug,
      regionId: goaRegion?._id,
      regionSlug: goaRegion?.slug,
      tz: 'Asia/Kolkata',
      centroid: { type: 'Point', coordinates: [73.8092, 15.5937] },
      aliases: [],
      popularity: 61,
      isActive: true,
      metadata: { }
    },
    {
      type: 'city',
      name: 'Calangute',
      slug: slugify('Calangute'),
      countryId: inCountry?._id,
      countrySlug: inCountry?.slug,
      regionId: goaRegion?._id,
      regionSlug: goaRegion?.slug,
      tz: 'Asia/Kolkata',
      centroid: { type: 'Point', coordinates: [73.7547, 15.5439] },
      aliases: [],
      popularity: 66,
      isActive: true,
      metadata: { }
    },
    // India metro
    {
      type: 'city',
      name: 'New Delhi',
      slug: slugify('New Delhi'),
      countryId: inCountry?._id,
      countrySlug: inCountry?.slug,
      tz: 'Asia/Kolkata',
      centroid: { type: 'Point', coordinates: [77.2090, 28.6139] },
      aliases: ['Delhi'],
      popularity: 95,
      isActive: true,
      metadata: { iataNearby: ['DEL'] }
    },
    {
      type: 'city',
      name: 'Mumbai',
      slug: slugify('Mumbai'),
      countryId: inCountry?._id,
      countrySlug: inCountry?.slug,
      tz: 'Asia/Kolkata',
      centroid: { type: 'Point', coordinates: [72.8777, 19.0760] },
      aliases: ['Bombay'],
      popularity: 97,
      isActive: true,
      metadata: { iataNearby: ['BOM'] }
    },
    // Italy / Lazio
    {
      type: 'city',
      name: 'Rome',
      slug: slugify('Rome'),
      countryId: itCountry?._id,
      countrySlug: itCountry?.slug,
      regionId: lazioRegion?._id,
      regionSlug: lazioRegion?.slug,
      tz: 'Europe/Rome',
      centroid: { type: 'Point', coordinates: [12.4964, 41.9028] },
      aliases: ['Roma'],
      popularity: 99,
      isActive: true,
      metadata: { iataNearby: ['FCO', 'CIA'] }
    }
  ];

  const cityOps = cities.map((c) => ({
    updateOne: {
      filter: { type: 'city', slug: c.slug, countrySlug: c.countrySlug },
      update: { $set: c },
      upsert: true
    }
  }));
  const result = await LocationMaster.bulkWrite(cityOps, { ordered: false });

  const matched = result.matchedCount || 0;
  const modified = result.modifiedCount || 0;
  const upserted =
    (result.upsertedCount !== undefined
      ? result.upsertedCount
      : (result.getUpsertedIds ? result.getUpsertedIds().length : 0)) || 0;

  console.log(`Locations seed complete: matched=${matched}, modified=${modified}, upserted=${upserted}`);
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
