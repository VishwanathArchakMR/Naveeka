// backend/scripts/seed_ai_samples.js
/* eslint-disable no-console */
require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/database');

// Inline lightweight model for demo samples (adjust if you already have one)
const aiSampleSchema = new mongoose.Schema(
  {
    title: String,
    role: String, // travel_guide | planner | social_captions
    input: Object, // { message, context }
    output: Object, // { text, suggestions[] }
    tags: [String]
  },
  { timestamps: true, collection: 'ai_samples' }
);
const AiSample = mongoose.models.AiSample || mongoose.model('AiSample', aiSampleSchema);

async function main() {
  await connectDB();
  console.log('Connected to MongoDB');

  const CLEAR = (process.env.SEED_CLEAR_AI || 'true') === 'true';
  if (CLEAR) {
    console.log('Clearing ai_samples...');
    await AiSample.deleteMany({});
  }

  const rows = [
    {
      title: '2-day Udupi temple plan',
      role: 'planner',
      input: {
        message: 'Plan a 2-day spiritual trip around Udupi with temples and light nature.',
        context: { region: 'Udupi', days: 2, preferences: ['Temples', 'Peaceful'] }
      },
      output: {
        text: 'Day 1: Udupi Sri Krishna Matha at 6:30 AM, breakfast at local Udupi joint, noon visit to Kaup lighthouse beach, evening darshan back at Matha. Day 2: Morning Pajaka Kshetra, lunch at traditional mess, sunset at Malpe sea walk.',
        suggestions: [
          { title: 'Find darshan slots', action: { type: 'search', query: 'darshan Udupi Sri Krishna Matha' } },
          { title: 'Nearby stays', action: { type: 'search', query: 'stay near Udupi temple' } }
        ]
      },
      tags: ['planner', 'template']
    },
    {
      title: 'Caption for waterfall reel',
      role: 'social_captions',
      input: {
        message: 'Short caption for a 10-second waterfall reel near a forest temple.',
        context: { categories: ['Nature', 'Temples'], emotions: ['Peaceful'] }
      },
      output: {
        text: 'Whispers of the forest, blessings in the mist. #Nature #Temples #Waterfall #Peaceful #IncredibleIndia',
        suggestions: [
          { title: 'Try a playful tone', action: { type: 'rephrase', tone: 'playful' } },
          { title: 'Add local tags', action: { type: 'augment', kind: 'hashtags' } }
        ]
      },
      tags: ['social', 'caption']
    },
    {
      title: 'Weekend coastal loop',
      role: 'travel_guide',
      input: {
        message: 'Suggest a relaxed coastal weekend with 2-3 spots and good veg food.',
        context: { days: 2, cuisine: 'veg', region: 'Karnataka Coast' }
      },
      output: {
        text: 'Start at Malpe beach for sunrise, brunch on Udupi classics, visit Kaup lighthouse for golden hour, and end day at a quiet estuary. Next day, temple stroll and a forest stream stop before heading back.',
        suggestions: [
          { title: 'Map this route', action: { type: 'map', places: ['Malpe', 'Kaup Lighthouse'] } },
          { title: 'Book a cottage', action: { type: 'search', query: 'eco cottages near Malpe' } }
        ]
      },
      tags: ['guide', 'coast']
    }
  ];

  console.log(`Seeding ${rows.length} AI samples...`);
  await AiSample.insertMany(rows);

  console.log('AI samples seed complete.');
  await mongoose.connection.close();
  console.log('Disconnected. ✅');
}

main().catch(async (e) => {
  console.error('Seed AI samples error:', e);
  try { await mongoose.connection.close(); } catch (_) {}
  process.exit(1);
});
