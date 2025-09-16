// C:\flutterapp\myapp\backend\services\messageService.js

'use strict';

const mongoose = require('mongoose');
const MessageThread = require('../models/MessageThread');
const Message = require('../models/Message');
const ReadReceipt = require('../models/ReadReceipt');

// ------------- Helpers -------------
function isObjectId(v) {
  return mongoose.Types.ObjectId.isValid(v);
}
function toObjectId(v) {
  return new mongoose.Types.ObjectId(v);
}
function coerceInt(v, def) {
  const n = parseInt(v, 10);
  return Number.isFinite(n) && n > 0 ? n : def;
}
function toISO(d) {
  return new Date(d).toISOString();
}
function sanitizeRegex(s) {
  return s ? String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') : '';
}
async function ensureParticipant(threadId, userId) {
  const t = await MessageThread.findById(threadId).select({ participants: 1 }).lean();
  if (!t) return false;
  return (t.participants || []).map(String).includes(String(userId));
}
function nowISO() {
  return toISO(Date.now());
}

// Participant state upsert (mute/archive/pin)
async function upsertParticipantState(threadId, userId, patch) {
  const filter = { _id: threadId, 'participantStates.userId': userId };
  const updateExisting = {
    $set: Object.fromEntries(
      Object.entries(patch).map(([k, v]) => [`participantStates.$[u].${k}`, v])
    )
  };
  const arrayFilters = [{ 'u.userId': userId }];
  const res = await MessageThread.updateOne(filter, updateExisting, { arrayFilters });
  if (res.matchedCount === 0) {
    await MessageThread.updateOne(
      { _id: threadId },
      { $addToSet: { participantStates: { userId, ...patch } } }
    );
  }
}

// ------------- Threads -------------
async function listThreads({
  userId,
  type,            // 'dm' | 'group'
  muted,           // boolean
  archived,        // boolean
  pinned,          // boolean
  q,               // search by title or participant name (title only here)
  cursor,          // ISO string for lastMessageAtISO before-cursor
  limit = 20
}) {
  const l = Math.min(coerceInt(limit, 20), 100);
  const match = {
    isActive: true,
    participants: toObjectId(userId)
  };
  if (type) match.type = type;
  if (typeof muted === 'boolean') {
    match.participantStates = { $elemMatch: { userId: toObjectId(userId), muted } };
  }
  if (typeof archived === 'boolean') {
    match.participantStates = { $elemMatch: { userId: toObjectId(userId), archived } };
  }
  if (typeof pinned === 'boolean') {
    match.participantStates = { $elemMatch: { userId: toObjectId(userId), pinned } };
  }
  if (q) {
    const rx = new RegExp(sanitizeRegex(q), 'i');
    match.title = rx;
  }
  if (cursor) {
    match.lastMessageAtISO = { $lt: cursor };
  }

  const items = await MessageThread.find(match)
    .sort({ lastMessageAtISO: -1, _id: -1 })
    .limit(l)
    .lean();

  const hasMore = items.length === l;
  return { items, hasMore, nextCursor: hasMore ? items[items.length - 1].lastMessageAtISO : null };
}

async function createThread({
  userId,
  type = 'dm',
  participants = [],
  title,
  icon,
  description
}) {
  const author = toObjectId(userId);
  const unique = Array.from(new Set([author.toString(), ...participants.map(String)])).map(toObjectId);

  if (type === 'dm' && unique.length !== 2) {
    throw new Error('DM must have exactly 2 unique participants');
  }

  // Avoid duplicate DM for same pair (order-independent)
  if (type === 'dm') {
    const existing = await MessageThread.findOne({
      type: 'dm',
      participants: { $all: unique, $size: 2 }
    }).lean();
    if (existing) return existing;
  }

  const now = nowISO();
  const doc = await MessageThread.create({
    type,
    participants: unique,
    title: type === 'group' ? title || 'New Group' : null,
    icon: type === 'group' ? icon || null : null,
    description: type === 'group' ? description || null : null,
    createdAtISO: now,
    updatedAtISO: now,
    lastMessageAtISO: now,
    isActive: true,
    participantStates: unique.map((uid) => ({ userId: uid, muted: false, archived: false, pinned: false }))
  });
  return doc.toObject();
}

async function getThreadById(threadId, userId) {
  const t = await MessageThread.findById(threadId).lean();
  if (!t) return null;
  if (!(t.participants || []).map(String).includes(String(userId))) return null;
  return t;
}

async function updateThread(threadId, userId, patch = {}) {
  const t = await getThreadById(threadId, userId);
  if (!t) return null;
  if (t.type !== 'group') return t; // only groups editable
  const allowed = {};
  if (patch.title !== undefined) allowed.title = patch.title;
  if (patch.icon !== undefined) allowed.icon = patch.icon;
  if (patch.description !== undefined) allowed.description = patch.description;

  const updated = await MessageThread.findByIdAndUpdate(
    threadId,
    { $set: { ...allowed, updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

async function addMembers(threadId, userId, userIds = []) {
  const t = await getThreadById(threadId, userId);
  if (!t) return null;
  if (t.type !== 'group') return t;

  const toAdd = userIds.map(toObjectId);
  const updated = await MessageThread.findByIdAndUpdate(
    threadId,
    {
      $addToSet: {
        participants: { $each: toAdd },
        participantStates: { $each: toAdd.map((uid) => ({ userId: uid, muted: false, archived: false, pinned: false })) }
      },
      $set: { updatedAtISO: nowISO() }
    },
    { new: true }
  ).lean();
  return updated;
}

async function removeMembers(threadId, userId, userIds = []) {
  const t = await getThreadById(threadId, userId);
  if (!t) return null;
  if (t.type !== 'group') return t;

  const toRemove = userIds.map(toObjectId);
  const updated = await MessageThread.findByIdAndUpdate(
    threadId,
    {
      $pull: {
        participants: { $in: toRemove },
        participantStates: { userId: { $in: toRemove } }
      },
      $set: { updatedAtISO: nowISO() }
    },
    { new: true }
  ).lean();
  return updated;
}

async function muteThread(threadId, userId) {
  await upsertParticipantState(threadId, toObjectId(userId), { muted: true });
  return { ok: true };
}
async function unmuteThread(threadId, userId) {
  await upsertParticipantState(threadId, toObjectId(userId), { muted: false });
  return { ok: true };
}
async function archiveThread(threadId, userId) {
  await upsertParticipantState(threadId, toObjectId(userId), { archived: true });
  return { ok: true };
}
async function unarchiveThread(threadId, userId) {
  await upsertParticipantState(threadId, toObjectId(userId), { archived: false });
  return { ok: true };
}
async function pinThread(threadId, userId) {
  await upsertParticipantState(threadId, toObjectId(userId), { pinned: true });
  return { ok: true };
}
async function unpinThread(threadId, userId) {
  await upsertParticipantState(threadId, toObjectId(userId), { pinned: false });
  return { ok: true };
}

// ------------- Read Receipts -------------
async function getThreadReceipts(threadId, userId) {
  const ok = await ensureParticipant(threadId, userId);
  if (!ok) return [];
  return ReadReceipt.find({ threadId }).lean();
}

async function markRead(threadId, userId, { messageId, atISO }) {
  const ok = await ensureParticipant(threadId, userId);
  if (!ok) return null;

  let lastId = null;
  if (messageId) {
    const msg = await Message.findById(messageId).select({ _id: 1, threadId: 1 }).lean();
    if (msg && String(msg.threadId) === String(threadId)) {
      lastId = msg._id;
    }
  } else {
    const latest = await Message.find({ threadId }).sort({ sentAtISO: -1, _id: -1 }).limit(1).lean();
    lastId = latest?.[0]?._id || null;
  }

  const payload = {
    threadId: toObjectId(threadId),
    userId: toObjectId(userId),
    lastReadMessageId: lastId,
    lastReadAtISO: atISO || nowISO()
  };

  const updated = await ReadReceipt.findOneAndUpdate(
    { threadId: payload.threadId, userId: payload.userId },
    { $set: payload },
    { upsert: true, new: true }
  ).lean();

  return updated;
}

// ------------- Messages -------------
async function listMessages({
  threadId,
  userId,
  before,         // messageId for backward pagination
  after,          // messageId for forward pagination
  limit = 50
}) {
  const ok = await ensureParticipant(threadId, userId);
  if (!ok) return { items: [], hasMoreBackward: false, hasMoreForward: false };

  const l = Math.min(coerceInt(limit, 50), 200);
  const q = { threadId: toObjectId(threadId) };

  const boundary = async (msgId) => {
    const m = await Message.findById(msgId).select({ sentAtISO: 1 }).lean();
    return m ? m.sentAtISO : null;
  };

  if (before) {
    const ts = await boundary(before);
    if (ts) q.sentAtISO = { $lt: ts };
    const items = await Message.find(q).sort({ sentAtISO: -1, _id: -1 }).limit(l).lean();
    items.reverse();
    const more = items.length === l;
    return { items, hasMoreBackward: more, hasMoreForward: true };
  }

  if (after) {
    const ts = await boundary(after);
    if (ts) q.sentAtISO = { $gt: ts };
    const items = await Message.find(q).sort({ sentAtISO: 1, _id: 1 }).limit(l).lean();
    const more = items.length === l;
    return { items, hasMoreBackward: true, hasMoreForward: more };
  }

  // Default: latest page
  const items = await Message.find(q).sort({ sentAtISO: -1, _id: -1 }).limit(l).lean();
  items.reverse();
  const more = items.length === l;
  return { items, hasMoreBackward: more, hasMoreForward: false };
}

async function sendMessage({
  threadId,
  userId,
  type = 'text',        // 'text'|'image'|'video'|'audio'|'file'|'location'
  text,
  attachments = [],
  location,             // { type:'Point', coordinates:[lng,lat] }
  replyTo               // messageId
}) {
  const ok = await ensureParticipant(threadId, userId);
  if (!ok) return null;

  const payload = {
    threadId: toObjectId(threadId),
    senderId: toObjectId(userId),
    type,
    text: text || null,
    attachments: attachments || [],
    location: type === 'location' ? location || null : null,
    replyTo: replyTo ? toObjectId(replyTo) : null,
    sentAtISO: nowISO(),
    editedAtISO: null,
    deleted: false,
    metadata: {}
  };

  const doc = await Message.create(payload);

  await MessageThread.updateOne(
    { _id: threadId },
    { $set: { lastMessageAtISO: payload.sentAtISO, updatedAtISO: payload.sentAtISO } }
  );

  return doc.toObject();
}

async function getMessageById(messageId, userId) {
  const m = await Message.findById(messageId).lean();
  if (!m) return null;
  const ok = await ensureParticipant(m.threadId, userId);
  if (!ok) return null;
  return m;
}

async function editMessage({ messageId, userId, text }) {
  const m = await Message.findById(messageId).select({ senderId: 1 }).lean();
  if (!m) return null;
  if (String(m.senderId) !== String(userId)) return null;

  const updated = await Message.findByIdAndUpdate(
    messageId,
    { $set: { text, editedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

async function deleteMessage(messageId, userId) {
  const m = await Message.findById(messageId).select({ senderId: 1 }).lean();
  if (!m) return null;
  if (String(m.senderId) !== String(userId)) return null;

  const updated = await Message.findByIdAndUpdate(
    messageId,
    { $set: { deleted: true, text: null, editedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

// ------------- Reactions -------------
async function addReaction({ messageId, userId, emoji }) {
  const m = await Message.findById(messageId).select({ threadId: 1 }).lean();
  if (!m) return null;
  const ok = await ensureParticipant(m.threadId, userId);
  if (!ok) return null;

  await Message.updateOne(
    { _id: messageId },
    { $addToSet: { reactions: { userId: toObjectId(userId), emoji } } }
  );
  return Message.findById(messageId).lean();
}

async function removeReaction({ messageId, userId, emoji }) {
  const m = await Message.findById(messageId).select({ threadId: 1 }).lean();
  if (!m) return null;
  const ok = await ensureParticipant(m.threadId, userId);
  if (!ok) return null;

  await Message.updateOne(
    { _id: messageId },
    { $pull: { reactions: { userId: toObjectId(userId), emoji } } }
  );
  return Message.findById(messageId).lean();
}

// ------------- GeoJSON export (location messages) -------------
async function getThreadGeoJSON(threadId, userId) {
  const ok = await ensureParticipant(threadId, userId);
  if (!ok) return { type: 'FeatureCollection', features: [] };

  const items = await Message.find({
    threadId: toObjectId(threadId),
    type: 'location',
    location: { $exists: true }
  })
    .select({ _id: 1, senderId: 1, text: 1, location: 1, sentAtISO: 1 })
    .lean();

  const features = [];
  for (const m of items) {
    if (m.location?.type === 'Point' && Array.isArray(m.location.coordinates)) {
      features.push({
        type: 'Feature',
        geometry: m.location,
        properties: {
          id: String(m._id),
          senderId: String(m.senderId),
          text: m.text || null,
          sentAtISO: m.sentAtISO
        }
      });
    }
  }
  return { type: 'FeatureCollection', features };
}

// ------------- SSE payload helper (optional) -------------
function toSSEEvent(event, data) {
  // Controllers stream this with text/event-stream and regular heartbeats
  // Example: res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)
  return { event, data, atISO: nowISO() };
}

module.exports = {
  // Threads
  listThreads,
  createThread,
  getThreadById,
  updateThread,
  addMembers,
  removeMembers,
  muteThread,
  unmuteThread,
  archiveThread,
  unarchiveThread,
  pinThread,
  unpinThread,

  // Receipts
  getThreadReceipts,
  markRead,

  // Messages
  listMessages,
  sendMessage,
  getMessageById,
  editMessage,
  deleteMessage,

  // Reactions
  addReaction,
  removeReaction,

  // Geo
  getThreadGeoJSON,

  // SSE helper
  toSSEEvent
};
