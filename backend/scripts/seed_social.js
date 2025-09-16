// backend/scripts/seed_social.js
/* eslint-disable no-console */
require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('../config/database');

// Core models
const User = require('../models/user');
const Place = require('../models/place');

// Social models
const UserSocial = require('../models/social/UserSocial');
const Follow = require('../models/social/Follow');
const Post = require('../models/social/Post');
const Comment = require('../models/social/Comment');
const Reaction = require('../models/social/Reaction');

// Helpers
const now = () => new Date();
const pickMany = (arr, n) => arr.slice().sort(() => 0.5 - Math.random()).slice(0, n); // shuffles then slices [9]
const pickOne = (arr) => arr[Math.floor(Math.random() * arr.length)]; // single random item [5][1]
const rand = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

async function upsertUser(u) {
  return User.findOneAndUpdate(
    { email: u.email },
    {
      $setOnInsert: {
        name: u.name,
        email: u.email,
        phone: u.phone,
        password: u.password
      }
    },
    { upsert: true, new: true }
  );
}

async function main() {
  const CLEAR = (process.env.SEED_CLEAR || 'true') === 'true';

  await connectDB();
  console.log('Connected to MongoDB');

  if (CLEAR) {
    console.log('Clearing social collections...');
    await Promise.all([
      UserSocial.deleteMany({}),
      Follow.deleteMany({}),
      Post.deleteMany({}),
      Comment.deleteMany({}),
      Reaction.deleteMany({})
    ]);
  }

  // Valid demo users
  const demoUsers = [
    { name: 'Ananya Rao', email: 'ananya.rao@example.com', phone: '201-555-0101', password: 'P@ssw0rd123' },
    { name: 'Rahul Iyer', email: 'rahul.iyer@example.com', phone: '201-555-0102', password: 'P@ssw0rd123' },
    { name: 'Meera Das', email: 'meera.das@example.com', phone: '201-555-0103', password: 'P@ssw0rd123' }
  ];

  console.log('Ensuring demo users exist (valid email + phone)...');
  const users = [];
  for (const u of demoUsers) {
    const doc = await upsertUser(u);
    users.push(doc);
  }

  // Social profiles
  console.log('Creating social profiles...');
  for (const u of users) {
    const baseHandle = (u.name || 'traveler').toLowerCase().replace(/[^a-z0-9]+/g, '').slice(0, 12);
    const handle = `${baseHandle}${String(u._id).slice(-4)}`;
    await UserSocial.findOneAndUpdate(
      { userId: u._id },
      {
        $set: {
          userId: u._id,
          handle,
          name: u.name,
          bio: 'Exploring spiritual India and hidden nature gems.',
          avatar: 'https://placehold.co/200x200?text=Traveler',
          links: ['https://instagram.com/traveos_demo'],
          preferences: ['Temples', 'Nature', 'Peaceful'],
          locationText: 'Karnataka, India',
          isVerified: true
        }
      },
      { upsert: true, new: true, runValidators: true }
    );
  }

  // Follow graph
  console.log('Creating follow relationships...');
  for (const a of users) {
    for (const b of users) {
      if (String(a._id) === String(b._id)) continue;
      await Follow.updateOne(
        { followerId: a._id, followeeId: b._id },
        { $setOnInsert: { followerId: a._id, followeeId: b._id, createdAt: now() } },
        { upsert: true }
      );
    }
  }

  // Place links if available
  const samplePlaces = await Place.find({ isApproved: true }).select('_id').limit(5);
  const placeIds = samplePlaces.map(p => p._id);

  // Posts
  console.log('Creating posts...');
  const mediaPool = [
    { type: 'image', url: 'https://placehold.co/1200x800?text=Temple', thumb: 'https://placehold.co/600x400?text=Temple' },
    { type: 'image', url: 'https://placehold.co/1200x800?text=Beach', thumb: 'https://placehold.co/600x400?text=Beach' },
    { type: 'image', url: 'https://placehold.co/1200x800?text=Forest', thumb: 'https://placehold.co/600x400?text=Forest' },
    { type: 'video', url: 'https://example.com/video.mp4', thumb: 'https://placehold.co/600x400?text=Video', dur: 12 }
  ];
  const kinds = ['photo', 'video', 'reel'];
  const emotions = ['Spiritual', 'Peaceful', 'Adventure'];
  const categories = ['Temples', 'Nature', 'Heritage', 'Stay Places'];
  const captions = [
    'Morning darshan at an ancient temple.',
    'Sunset by the coastal beach – pure bliss.',
    'Trail through the forest to a hidden waterfall.',
    'Peaceful moments at the ashram.'
  ];

  const createdPosts = [];
  for (const u of users) {
    for (let i = 0; i < 4; i++) {
      const post = await Post.create({
        authorId: u._id,
        kind: kinds[i % kinds.length],
        caption: captions[i % captions.length],
        tags: ['#travel', '#india', '#traveos'],
        emotions: pickMany(emotions, 1),
        categories: pickMany(categories, 2),
        placeRefs: pickMany(placeIds, rand(0, Math.min(2, placeIds.length))),
        regionRefs: [],
        media: pickMany(mediaPool, 2),
        visibility: 'public',
        metrics: {
          likes: rand(5, 50),
          comments: rand(2, 12),
          shares: rand(0, 5),
          views: rand(50, 500)
        },
        createdAt: new Date(Date.now() - rand(0, 5) * 24 * 60 * 60 * 1000)
      });
      createdPosts.push(post);
    }
  }

  // Reactions and comments
  console.log('Adding reactions and comments...');
  const commentTexts = [
    'This place looks amazing!',
    'Added to my wishlist!',
    'Spiritual vibes ✨',
    'Nature at its best.',
    'Must visit on my next trip.'
  ];

  for (const post of createdPosts) {
    const reactors = pickMany(users, rand(1, users.length));
    for (const r of reactors) {
      await Reaction.updateOne(
        { postId: post._id, userId: r._id, kind: 'like' },
        { $setOnInsert: { postId: post._id, userId: r._id, kind: 'like', createdAt: now() } },
        { upsert: true }
      );

      if (Math.random() > 0.5) {
        await Comment.create({
          postId: post._id,
          authorId: r._id,
          text: pickOne(commentTexts), // ensure string, not array [5][2]
          rating: rand(0, 5),
          images: [],
          createdAt: new Date(Date.now() - rand(0, 3) * 60 * 60 * 1000)
        });
      }
    }
  }

  // Update profile counters
  console.log('Updating profile counters...');
  for (const u of users) {
    const followers = await Follow.countDocuments({ followeeId: u._id });
    const following = await Follow.countDocuments({ followerId: u._id });
    const postsCount = await Post.countDocuments({ authorId: u._id });
    await UserSocial.updateOne(
      { userId: u._id },
      { $set: { 'counts.followers': followers, 'counts.following': following, 'counts.posts': postsCount } }
    );
  }

  console.log('Social seed complete.');
  await mongoose.connection.close();
  console.log('Disconnected. ✅');
}

main().catch(async (e) => {
  console.error('Seed error:', e);
  try { await mongoose.connection.close(); } catch (_) {}
  process.exit(1);
});

