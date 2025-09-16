// C:\flutterapp\myapp\backend\scripts\seed_flights.js

'use strict';

/**
 * Seed Flights collection with realistic sample data:
 * - IATA-based routing (e.g., GOX -> DEL, GOI -> BOM, DEL -> FCO)
 * - Single and multi-segment itineraries with ISO-like departure/arrival strings
 * - GeoJSON LineString [ [lng,lat], ... ] per itinerary for map overlays
 * - Airline/carrier codes, fare currency/amount, cabins, popularity metrics
 *
 * Usage:
 *   node scripts/seed_flights.js --reset
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_flights.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

// Adjust model paths if different in your project
const Flight = require('../models/Flight');
const Airport = require('../models/Airport');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function offerKeyFrom(o) {
  // Stable key for upsert: CARRIER-NUMBER-YYYYMMDD-FROM-TO
  const d = (o.departureISO || '').slice(0, 10).replace(/-/g, '');
  return `${o.carrier}-${o.number}-${d}-${o.from}-${o.to}`.toUpperCase();
}

function midPoint(a, b) {
  // Simple midpoint for a nicer line bend if needed; here we just use endpoints.
  return [(a + b) / 2, (a + b) / 2];
}

const FALLBACK_AIRPORT_COORDS = {
  GOX: [73.839, 15.723],
  GOI: [73.831, 15.380],
  DEL: [77.103, 28.556],
  BOM: [72.871, 19.089],
  FCO: [12.250, 41.800],
  CIA: [12.595, 41.800]
};

async function connect() {
  await mongoose.connect(MONGODB_URI, { family: 4 });
  mongoose.connection.on('error', (err) => {
    console.error('Mongo connection error:', err);
  });
  console.log('Connected to MongoDB:', mongoose.connection.name);
}

async function getAirportByIata(iata) {
  const doc = await Airport.findOne({ iata: iata?.toUpperCase() }).lean();
  if (doc?.location?.coordinates?.length === 2) {
    return { coord: doc.location.coordinates, refId: doc._id };
  }
  const fallback = FALLBACK_AIRPORT_COORDS[iata?.toUpperCase()];
  return { coord: fallback || [0, 0], refId: undefined };
}

async function buildRouteLine(iataFrom, iataTo) {
  const from = await getAirportByIata(iataFrom);
  const to = await getAirportByIata(iataTo);
  // Use endpoints (and optionally a midpoint) for a simple route polyline
  const coords = [from.coord, to.coord];
  return {
    geojson: { type: 'LineString', coordinates: coords },
    fromRefId: from.refId,
    toRefId: to.refId
  };
}

async function buildSamples() {
  // Sample flights:
  // 1) Air India AI 866: GOX -> DEL (direct)
  const r1 = await buildRouteLine('GOX', 'DEL');
  const ai866 = {
    offerKey: offerKeyFrom({
      carrier: 'AI',
      number: '866',
      departureISO: '2025-09-21T08:25:00+05:30',
      from: 'GOX',
      to: 'DEL'
    }),
    carrier: 'AI',
    number: '866',
    airlineName: 'Air India',
    from: 'GOX',
    to: 'DEL',
    slices: [
      {
        segments: [
          {
            marketingCarrier: 'AI',
            operatingCarrier: 'AI',
            flightNumber: '866',
            from: { iata: 'GOX', refId: r1.fromRefId || null },
            to: { iata: 'DEL', refId: r1.toRefId || null },
            departureISO: '2025-09-21T08:25:00+05:30',
            arrivalISO: '2025-09-21T11:05:00+05:30',
            durationMin: 160,
            cabin: 'ECONOMY',
            aircraft: 'A320'
          }
        ]
      }
    ],
    routeGeoJSON: r1.geojson,
    price: { amount: 6999, currency: 'INR' },
    baggage: { carryOnKg: 7, checkedInKg: 15 },
    popularity: 86,
    viewCount: 10450,
    isActive: true,
    metadata: { refundable: true }
  };

  // 2) IndiGo 6E 234: GOI -> BOM (direct)
  const r2 = await buildRouteLine('GOI', 'BOM');
  const sixE234 = {
    offerKey: offerKeyFrom({
      carrier: '6E',
      number: '234',
      departureISO: '2025-09-21T10:10:00+05:30',
      from: 'GOI',
      to: 'BOM'
    }),
    carrier: '6E',
    number: '234',
    airlineName: 'IndiGo',
    from: 'GOI',
    to: 'BOM',
    slices: [
      {
        segments: [
          {
            marketingCarrier: '6E',
            operatingCarrier: '6E',
            flightNumber: '234',
            from: { iata: 'GOI', refId: r2.fromRefId || null },
            to: { iata: 'BOM', refId: r2.toRefId || null },
            departureISO: '2025-09-21T10:10:00+05:30',
            arrivalISO: '2025-09-21T11:30:00+05:30',
            durationMin: 80,
            cabin: 'ECONOMY',
            aircraft: 'A320neo'
          }
        ]
      }
    ],
    routeGeoJSON: r2.geojson,
    price: { amount: 3499, currency: 'INR' },
    baggage: { carryOnKg: 7, checkedInKg: 15 },
    popularity: 78,
    viewCount: 8450,
    isActive: true,
    metadata: { refundable: false }
  };

  // 3) ITA Airways AZ 203: DEL -> FCO (direct, long-haul)
  const r3 = await buildRouteLine('DEL', 'FCO');
  const az203 = {
    offerKey: offerKeyFrom({
      carrier: 'AZ',
      number: '203',
      departureISO: '2025-09-22T02:30:00+05:30',
      from: 'DEL',
      to: 'FCO'
    }),
    carrier: 'AZ',
    number: '203',
    airlineName: 'ITA Airways',
    from: 'DEL',
    to: 'FCO',
    slices: [
      {
        segments: [
          {
            marketingCarrier: 'AZ',
            operatingCarrier: 'AZ',
            flightNumber: '203',
            from: { iata: 'DEL', refId: r3.fromRefId || null },
            to: { iata: 'FCO', refId: r3.toRefId || null },
            departureISO: '2025-09-22T02:30:00+05:30',
            arrivalISO: '2025-09-22T07:40:00+02:00',
            durationMin: 520,
            cabin: 'ECONOMY',
            aircraft: 'A330-900'
          }
        ]
      }
    ],
    routeGeoJSON: r3.geojson,
    price: { amount: 459, currency: 'EUR' },
    baggage: { carryOnKg: 8, checkedInKg: 23 },
    popularity: 91,
    viewCount: 22400,
    isActive: true,
    metadata: { meal: 'included' }
  };

  // 4) Vistara UK 870: GOX -> DEL -> FCO (one-stop via DEL)
  const r4a = await buildRouteLine('GOX', 'DEL');
  const r4b = await buildRouteLine('DEL', 'FCO');
  const uk870 = {
    offerKey: offerKeyFrom({
      carrier: 'UK',
      number: '870',
      departureISO: '2025-09-21T09:15:00+05:30',
      from: 'GOX',
      to: 'FCO'
    }),
    carrier: 'UK',
    number: '870',
    airlineName: 'Vistara',
    from: 'GOX',
    to: 'FCO',
    slices: [
      {
        segments: [
          {
            marketingCarrier: 'UK',
            operatingCarrier: 'UK',
            flightNumber: '870',
            from: { iata: 'GOX', refId: r4a.fromRefId || null },
            to: { iata: 'DEL', refId: r4a.toRefId || null },
            departureISO: '2025-09-21T09:15:00+05:30',
            arrivalISO: '2025-09-21T11:45:00+05:30',
            durationMin: 150,
            cabin: 'ECONOMY',
            aircraft: 'A320'
          },
          {
            marketingCarrier: 'UK',
            operatingCarrier: 'AZ', // interline
            flightNumber: '203',
            from: { iata: 'DEL', refId: r4b.fromRefId || null },
            to: { iata: 'FCO', refId: r4b.toRefId || null },
            departureISO: '2025-09-21T21:30:00+05:30',
            arrivalISO: '2025-09-22T02:40:00+02:00',
            durationMin: 520,
            cabin: 'ECONOMY',
            aircraft: 'A330'
          }
        ]
      }
    ],
    // For multi-segment, merge polylines (simplified as array of segments)
    routeGeoJSON: {
      type: 'FeatureCollection',
      features: [
        { type: 'Feature', geometry: r4a.geojson, properties: { leg: 1 } },
        { type: 'Feature', geometry: r4b.geojson, properties: { leg: 2 } }
      ]
    },
    price: { amount: 629, currency: 'EUR' },
    baggage: { carryOnKg: 7, checkedInKg: 23 },
    popularity: 84,
    viewCount: 13250,
    isActive: true,
    metadata: { connection: { via: 'DEL', layoverMin: 590 } }
  };

  return [ai866, sixE234, az203, uk870];
}

async function seed({ reset = false } = {}) {
  if (reset) {
    await Flight.deleteMany({});
    console.log('Cleared Flights collection');
  }

  const offers = await buildSamples();

  // Upsert by offerKey to keep the script idempotent
  const ops = offers.map((o) => ({
    updateOne: {
      filter: { offerKey: o.offerKey },
      update: { $set: o },
      upsert: true
    }
  }));

  const result = await Flight.bulkWrite(ops, { ordered: false });
  const matched = result.matchedCount || 0;
  const modified = result.modifiedCount || 0;
  const upserted = (result.upsertedCount !== undefined
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
