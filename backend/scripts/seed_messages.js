// C:\flutterapp\myapp\backend\scripts\seed_messages.js

'use strict';

/**
 * Seeds messaging data:
 * - Requires existing users; pass user IDs via --users=<id1,id2,id3,...>
 * - Creates a DM thread between first two users and a group thread with all users
 * - Inserts sample messages (text/image/location), reactions, and read receipts
 *
 * Usage:
 *   node scripts/seed_messages.js --users=64f0...a1,64f0...b2,64f0...c3 --reset
 *   MONGODB_URI="mongodb://127.0.0.1:27017/myapp" node scripts/seed_messages.js --users=<ids>
 */

require('dotenv').config();
const mongoose = require('mongoose');

const MessageThread = require('../models/MessageThread');   // adjust paths if different
const Message = require('../models/Message');
const ReadReceipt = require('../models/ReadReceipt');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/myapp';

function parseUsersArg() {
  const arg = process.argv.find((a) => a.startsWith('--users='));
  if (!arg) return [];
  return arg
    .split('=')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

function toObjectId(id) {
  return new mongoose.Types.ObjectId(id);
}

function iso(dt) {
  return new Date(dt).toISOString();
}

async function connect() {
  await mongoose.connect(MONGODB_URI, { family: 4 });
  mongoose.connection.on('error', (err) => {
    console.error('Mongo connection error:', err);
  });
  console.log('Connected to MongoDB:', mongoose.connection.name);
}

async function ensureDMThread(userA, userB) {
  const seedKey = `seed:dm:${userA.toString().slice(-6)}-${userB.toString().slice(-6)}`;
  const existing = await MessageThread.findOne({ type: 'dm', 'metadata.seedKey': seedKey }).lean();
  if (existing) return existing;

  const doc = await MessageThread.create({
    type: 'dm',
    participants: [userA, userB],
    title: null,
    icon: null,
    metadata: { seedKey },
    isActive: true
  });
  return doc.toObject();
}

async function ensureGroupThread(users) {
  const seedKey = `seed:group:${users.map((u) => u.toString().slice(-4)).join('-')}`;
  const existing = await MessageThread.findOne({ type: 'group', 'metadata.seedKey': seedKey }).lean();
  if (existing) return existing;

  const doc = await MessageThread.create({
    type: 'group',
    participants: users,
    title: 'Trip Planning',
    icon: '🗺️',
    metadata: { seedKey },
    isActive: true
  });
  return doc.toObject();
}

async function seedMessagesForThread(thread, users) {
  // Build some sample messages
  const now = new Date();
  const t0 = new Date(now.getTime() - 1000 * 60 * 60); // 1h ago
  const t1 = new Date(now.getTime() - 1000 * 45 * 60); // 45m ago
  const t2 = new Date(now.getTime() - 1000 * 30 * 60); // 30m ago
  const t3 = new Date(now.getTime() - 1000 * 15 * 60); // 15m ago

  const [u1, u2, u3] = users;

  const msgs = [
    {
      threadId: thread._id,
      senderId: u1,
      type: 'text',
      text: 'Hey all, sharing the tentative plan for Goa. Thoughts?',
      sentAtISO: iso(t0),
      attachments: [],
      metadata: { seed: true }
    },
    {
      threadId: thread._id,
      senderId: u2 || u1,
      type: 'image',
      text: 'Beach vibe reference!',
      sentAtISO: iso(t1),
      attachments: [
        { kind: 'image', url: 'https://example-cdn/chat/beach_ref.jpg', width: 1600, height: 900 }
      ],
      metadata: { seed: true }
    },
    {
      threadId: thread._id,
      senderId: u3 || u2 || u1,
      type: 'location',
      text: 'Meet here?',
      sentAtISO: iso(t2),
      location: {
        type: 'Point',
        coordinates: [73.8278, 15.4989] // Panaji [lng, lat]
      },
      metadata: { seed: true }
    },
    {
      threadId: thread._id,
      senderId: u1,
      type: 'text',
      text: 'Booked Riviera Bay Resort from 21–24 Sep. 🎉',
      sentAtISO: iso(t3),
      attachments: [],
      metadata: { seed: true }
    }
  ];

  // Idempotent insert: upsert by a composite natural key (threadId + sentAtISO + senderId + text)
  const ops = msgs.map((m) => ({
    updateOne: {
      filter: {
        threadId: m.threadId,
        sentAtISO: m.sentAtISO,
        senderId: m.senderId,
        text: m.text
      },
      update: { $setOnInsert: m },
      upsert: true
    }
  }));

  await Message.bulkWrite(ops, { ordered: false });

  // Fetch the inserted/updated messages back to attach reactions/receipts
  const fetched = await Message.find({ threadId: thread._id })
    .sort({ sentAtISO: 1 })
    .limit(10)
    .lean();

  // Reactions on most recent message
  const lastMsg = fetched[fetched.length - 1];
  if (lastMsg) {
    await Message.updateOne(
      { _id: lastMsg._id },
      {
        $addToSet: {
          reactions: { userId: u2 || u1, emoji: '🎉' },
        }
      }
    );
  }

  // Mark read up to last message for all participants
  const rrOps = (users || []).map((uid) => ({
    updateOne: {
      filter: { threadId: thread._id, userId: uid },
      update: {
        $set: {
          threadId: thread._id,
          userId: uid,
          lastReadMessageId: lastMsg ? lastMsg._id : null,
          lastReadAtISO: iso(new Date())
        }
      },
      upsert: true
    }
  }));
  await ReadReceipt.bulkWrite(rrOps, { ordered: false });
}

async function seed({ reset = false, userIds = [] } = {}) {
  if (userIds.length < 2) {
    throw new Error('Provide at least 2 user IDs with --users=<id1,id2,...>');
  }

  if (reset) {
    // Only delete seeded data, not all threads/messages
    await Message.deleteMany({ 'metadata.seed': true });
    await ReadReceipt.deleteMany({ lastReadAtISO: { $exists: true }, });
    await MessageThread.deleteMany({ 'metadata.seedKey': { $regex: '^seed:' } });
    console.log('Cleared previously seeded messaging data');
  }

  const users = userIds.map(toObjectId);

  // Create DM (first two users)
  const dm = await ensureDMThread(users, users);

  // Create Group (all users)
  const group = await ensureGroupThread(users);

  // Seed messages
  await seedMessagesForThread(dm, [users, users]);
  await seedMessagesForThread(group, users);

  console.log('Seeded messaging threads and messages');
}

async function main() {
  const args = process.argv.slice(2);
  const reset = args.includes('--reset');
  const users = parseUsersArg();

  try {
    await connect();
    await seed({ reset, userIds: users });
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
