// backend/scripts/seed_experiences.js
/* eslint-disable no-console */
require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/database');

const Experience = require('../models/booking/Experience');
const Place = require('../models/place'); // optional linkage for richer cards

async function main() {
  await connectDB();
  console.log('Connected to MongoDB');

  const CLEAR = (process.env.SEED_CLEAR_EXPERIENCES || 'true') === 'true';
  if (CLEAR) {
    console.log('Clearing experiences...');
    await Experience.deleteMany({});
  }

  // Try to fetch a handful of approved places to associate
  const places = await Place.find({ isApproved: true }).select('_id name').limit(10);
  const placeIdOrNull = (i) => (places[i % (places.length || 1)]?._id || null);

  const base = Date.now();
  const mkTime = (d) => new Date(base - d * 24 * 60 * 60 * 1000);

  const rows = [
    {
      type: 'stay',
      title: 'Sthala Sthayi Heritage Stay',
      subtitle: 'Courtyard homestay near ancient temple town',
      description: 'Wake up to temple bells and piping hot filter coffee. Traditional meals, guided walks to heritage shrines.',
      placeId: placeIdOrNull(0),
      regionRefs: [],
      media: [
        'https://placehold.co/1200x800?text=Heritage+Stay',
        'https://placehold.co/1200x800?text=Courtyard'
      ],
      basePrice: 3200,
      currency: 'INR',
      providerUrl: 'https://example.com/partners/heritage-stay',
      tags: ['Temples', 'Heritage', 'Peaceful'],
      createdAt: mkTime(0)
    },
    {
      type: 'darshan',
      title: 'Early Morning Special Darshan',
      subtitle: 'Beat the crowd with a serene start',
      description: 'Priority entry slot at a renowned temple. Includes prasad and a short guided ritual overview.',
      placeId: placeIdOrNull(1),
      regionRefs: [],
      media: [
        'https://placehold.co/1200x800?text=Darshan',
        'https://placehold.co/1200x800?text=Temple+Entry'
      ],
      basePrice: 599,
      currency: 'INR',
      providerUrl: 'https://example.com/partners/darshan',
      tags: ['Spiritual', 'Temples'],
      createdAt: mkTime(1)
    },
    {
      type: 'activity',
      title: 'Forest Waterfall Hike',
      subtitle: 'Guided trail to a hidden cascade',
      description: 'Half-day hike through lush forest with local naturalist. Safe route, snacks, and photo stops included.',
      placeId: placeIdOrNull(2),
      regionRefs: [],
      media: [
        'https://placehold.co/1200x800?text=Waterfall',
        'https://placehold.co/1200x800?text=Forest+Trail'
      ],
      basePrice: 1499,
      currency: 'INR',
      providerUrl: 'https://example.com/partners/waterfall-hike',
      tags: ['Nature', 'Adventure'],
      createdAt: mkTime(2)
    },
    {
      type: 'transport',
      title: 'Airport Pickup (Sedan)',
      subtitle: 'Reliable transfer to temple town',
      description: 'Comfortable sedan with professional driver. Includes tolls and flexible wait time for delays.',
      placeId: null,
      regionRefs: [],
      media: [
        'https://placehold.co/1200x800?text=Airport+Pickup',
        'https://placehold.co/1200x800?text=Sedan'
      ],
      basePrice: 2200,
      currency: 'INR',
      providerUrl: 'https://example.com/partners/airport-transfer',
      tags: ['Convenience'],
      createdAt: mkTime(3)
    },
    {
      type: 'stay',
      title: 'Beachfront Eco Cottages',
      subtitle: 'Sunrise views and sea breeze',
      description: 'Sustainable cottages by the coast. Fresh seafood, hammock zones, and stargazing nights.',
      placeId: placeIdOrNull(3),
      regionRefs: [],
      media: [
        'https://placehold.co/1200x800?text=Eco+Cottage',
        'https://placehold.co/1200x800?text=Beachfront'
      ],
      basePrice: 4800,
      currency: 'INR',
      providerUrl: 'https://example.com/partners/eco-cottages',
      tags: ['Nature', 'Stay Places'],
      createdAt: mkTime(4)
    },
    {
      type: 'activity',
      title: 'Backwater Kayaking',
      subtitle: 'Gentle paddling through mangroves',
      description: 'Sunset slot with safety briefing and guide. Suitable for beginners and families.',
      placeId: placeIdOrNull(4),
      regionRefs: [],
      media: [
        'https://placehold.co/1200x800?text=Kayak',
        'https://placehold.co/1200x800?text=Backwaters'
      ],
      basePrice: 999,
      currency: 'INR',
      providerUrl: 'https://example.com/partners/kayaking',
      tags: ['Adventure', 'Nature'],
      createdAt: mkTime(5)
    }
  ];

  // Upsert-like behavior: for demo purposes, just insertMany after clear
  console.log(`Seeding ${rows.length} experiences...`);
  await Experience.insertMany(rows);

  console.log('Experiences seed complete.');
  await mongoose.connection.close();
  console.log('Disconnected. ✅');
}

main().catch(async (e) => {
  console.error('Seed experiences error:', e);
  try { await mongoose.connection.close(); } catch (_) {}
  process.exit(1);
});
