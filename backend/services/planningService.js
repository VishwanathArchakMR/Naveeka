// C:\flutterapp\myapp\backend\services\planningService.js

'use strict';

const mongoose = require('mongoose');
const TripGroup = require('../models/TripGroup');

// ---------- Helpers ----------
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
  return new Date(d).toISOString(); // ISO 8601 for unambiguous sorting/parsing
}
function sanitizeRegex(s) {
  return s ? String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&') : '';
}
function nowISO() {
  return toISO(Date.now());
}

// ICS date-time in UTC as YYYYMMDDTHHMMSSZ
function toICSDateUTC(d) {
  const z = new Date(d);
  const s = z.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
  // Result like 20250921T083000Z
  return s;
}

// Ensure membership
async function ensureMember(groupId, userId) {
  const g = await TripGroup.findById(groupId).select({ ownerId: 1, members: 1 }).lean();
  if (!g) return false;
  const set = new Set([String(g.ownerId), ...(g.members || []).map(String)]);
  return set.has(String(userId));
}

// Reindex seq per dayOffset (stable sort by existing seq)
function reindexItinerary(items) {
  const byDay = new Map();
  for (const it of items) {
    const d = it.dayOffset || 0;
    if (!byDay.has(d)) byDay.set(d, []);
    byDay.get(d).push(it);
  }
  const result = [];
  for (const [day, arr] of byDay.entries()) {
    arr.sort((a, b) => (a.seq ?? 0) - (b.seq ?? 0));
    arr.forEach((it, idx) => result.push({ ...it, dayOffset: day, seq: idx }));
  }
  return result;
}

// ---------- Groups ----------
async function listGroups({
  userId,
  cursor,            // ISO string to paginate by updatedAtISO descending
  limit = 20,
  destination,
  active            // boolean
}) {
  const l = Math.min(coerceInt(limit, 20), 100);
  const match = {
    isActive: active == null ? { $in: [true, false] } : !!active,
    $or: [{ ownerId: toObjectId(userId) }, { members: toObjectId(userId) }]
  };
  if (destination) {
    const rx = new RegExp(sanitizeRegex(destination), 'i');
    match['settings.destination'] = rx;
  }
  if (cursor) {
    match.updatedAtISO = { $lt: cursor };
  }

  const items = await TripGroup.find(match)
    .select({
      name: 1,
      slug: 1,
      cover: 1,
      ownerId: 1,
      members: 1,
      roles: 1,
      startDate: 1,
      endDate: 1,
      settings: 1,
      updatedAtISO: 1,
      popularity: 1,
      viewCount: 1
    })
    .sort({ updatedAtISO: -1, _id: -1 })
    .limit(l)
    .lean();

  const hasMore = items.length === l;
  return { items, hasMore, nextCursor: hasMore ? items[items.length - 1].updatedAtISO : null };
}

async function createGroup({
  ownerId,
  name,
  cover,
  settings = {},        // { destination, currency, tz }
  startDate,
  endDate,
  members = []
}) {
  const owner = toObjectId(ownerId);
  const uniqMembers = Array.from(new Set(members.map(String))).map(toObjectId);
  const roles = Object.fromEntries([owner, ...uniqMembers].map((id, idx) => [String(id), idx === 0 ? 'admin' : 'member']));
  const now = nowISO();

  const doc = await TripGroup.create({
    name: name || 'New Trip',
    slug: (name || 'New Trip').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, ''),
    cover: cover || null,
    ownerId: owner,
    members: uniqMembers,
    roles,
    startDate: startDate ? new Date(startDate) : null,
    endDate: endDate ? new Date(endDate) : null,
    settings,
    itinerary: [],
    budget: { baseCurrency: settings?.currency || 'INR', expenses: [] },
    checklist: [],
    documents: [],
    likesCount: 0,
    viewCount: 0,
    popularity: 0,
    isActive: true,
    createdAtISO: now,
    updatedAtISO: now,
    metadata: {}
  });

  return doc.toObject();
}

async function getGroupById(groupId, userId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const g = await TripGroup.findById(groupId).lean();
  if (!g) return null;

  // Aggregates
  const expenses = Array.isArray(g.budget?.expenses) ? g.budget.expenses : [];
  const byCurrency = new Map();
  for (const e of expenses) {
    const cur = e.currency || g.budget?.baseCurrency || 'INR';
    byCurrency.set(cur, (byCurrency.get(cur) || 0) + (e.amount || 0));
  }
  const expenseSummary = Array.from(byCurrency.entries()).map(([currency, total]) => ({ currency, total }));

  const itineraryCount = Array.isArray(g.itinerary) ? g.itinerary.length : 0;

  return { ...g, expenseSummary, itineraryCount };
}

async function updateGroup(groupId, userId, patch = {}) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const allowed = {};
  for (const k of ['name', 'cover', 'settings', 'startDate', 'endDate']) {
    if (patch[k] !== undefined) allowed[k] = patch[k];
  }
  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $set: { ...allowed, updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

async function removeOrLeaveGroup(groupId, userId) {
  const g = await TripGroup.findById(groupId).select({ ownerId: 1, members: 1 }).lean();
  if (!g) return { ok: true };

  if (String(g.ownerId) === String(userId)) {
    await TripGroup.deleteOne({ _id: groupId });
    return { ok: true, removed: true };
  }
  await TripGroup.updateOne(
    { _id: groupId },
    { $pull: { members: toObjectId(userId) }, $unset: { [`roles.${userId}`]: '' }, $set: { updatedAtISO: nowISO() } }
  );
  return { ok: true, removed: false };
}

// ---------- Members & Roles ----------
async function listMembers(groupId, userId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return [];
  const g = await TripGroup.findById(groupId).select({ ownerId: 1, members: 1, roles: 1 }).lean();
  return { ownerId: g.ownerId, members: g.members || [], roles: g.roles || {} };
}

async function addMembers(groupId, userId, userIds = []) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const ids = userIds.map(toObjectId);
  const roleSets = Object.fromEntries(ids.map((id) => [String(id), 'member']));
  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    {
      $addToSet: { members: { $each: ids } },
      $set: Object.fromEntries(Object.entries(roleSets).map(([k, v]) => [`roles.${k}`, v])),
      $setOnInsert: {},
      $currentDate: { updatedAtISO: true }
    },
    { new: true }
  ).lean();
  return updated;
}

async function removeMembers(groupId, userId, userIds = []) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const ids = userIds.map(toObjectId);
  const unsetRoles = Object.fromEntries(userIds.map((id) => [`roles.${id}`, '']));
  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $pull: { members: { $in: ids } }, $unset: unsetRoles, $set: { updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

async function setRoles(groupId, userId, roles = {}) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;
  const setPaths = Object.fromEntries(Object.entries(roles).map(([uid, role]) => [`roles.${uid}`, role]));
  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $set: { ...setPaths, updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

// ---------- Itinerary ----------
async function listItinerary(groupId, userId, { dayOffset, tags, cursor, limit = 100 } = {}) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return { items: [], hasMore: false };

  const g = await TripGroup.findById(groupId).select({ itinerary: 1 }).lean();
  let items = Array.isArray(g?.itinerary) ? [...g.itinerary] : [];

  if (dayOffset != null) {
    items = items.filter((it) => (it.dayOffset || 0) === Number(dayOffset));
  }
  if (tags) {
    const set = new Set((Array.isArray(tags) ? tags : String(tags).split(',').map((s) => s.trim())).filter(Boolean));
    if (set.size) items = items.filter((it) => Array.isArray(it.tags) && it.tags.some((t) => set.has(t)));
  }
  items.sort((a, b) => (a.dayOffset - b.dayOffset) || (a.seq - b.seq) || (new Date(a.startISO || 0) - new Date(b.startISO || 0)));

  // Cursor by composite key startISO+_id serialized; here simple ISO cursor on startISO descending
  if (cursor) {
    items = items.filter((it) => !it.startISO || String(it.startISO) < String(cursor));
  }

  const l = Math.min(coerceInt(limit, 100), 500);
  const page = items.slice(0, l);
  const hasMore = items.length > l;
  const nextCursor = hasMore ? page[page.length - 1].startISO || null : null;

  return { items: page, hasMore, nextCursor };
}

async function addItineraryItem(groupId, userId, payload) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const g = await TripGroup.findById(groupId).select({ itinerary: 1 }).lean();
  const items = Array.isArray(g?.itinerary) ? g.itinerary : [];
  const day = payload.dayOffset || 0;
  const seq = Number.isFinite(payload.seq) ? payload.seq : items.filter((i) => (i.dayOffset || 0) === day).length;

  const item = {
    dayOffset: day,
    seq,
    title: payload.title,
    type: payload.type || 'activity',
    entityType: payload.entityType || null,
    entityId: payload.entityId || null,
    startISO: payload.startISO ? toISO(payload.startISO) : null,
    endISO: payload.endISO ? toISO(payload.endISO) : null,
    durationMin: payload.durationMin || null,
    location: payload.location || null, // GeoJSON Point [lng,lat]
    address: payload.address || null,
    notes: payload.notes || null,
    tags: payload.tags || [],
    photos: payload.photos || [],
    meta: payload.meta || {}
  };

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $push: { itinerary: item }, $set: { updatedAtISO: nowISO() } },
    { new: true }
  ).lean();

  // Reindex for consistency (seq continuous)
  const reindexed = reindexItinerary(updated.itinerary || []);
  const final = await TripGroup.findByIdAndUpdate(
    groupId,
    { $set: { itinerary: reindexed, updatedAtISO: nowISO() } },
    { new: true }
  ).lean();

  return final;
}

async function updateItineraryItem(groupId, userId, itemId, patch = {}) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const g = await TripGroup.findById(groupId).lean();
  if (!g) return null;

  const items = Array.isArray(g.itinerary) ? g.itinerary.map((x) => ({ ...x })) : [];
  const idx = items.findIndex((x) => String(x._id) === String(itemId));
  if (idx < 0) return null;

  const it = items[idx];
  for (const k of ['title', 'type', 'entityType', 'entityId', 'startISO', 'endISO', 'durationMin', 'location', 'address', 'notes', 'tags', 'photos', 'meta']) {
    if (patch[k] !== undefined) it[k] = patch[k];
  }
  if (patch.dayOffset != null) it.dayOffset = patch.dayOffset;
  if (patch.seq != null) it.seq = patch.seq;

  const reindexed = reindexItinerary(items);
  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $set: { itinerary: reindexed, updatedAtISO: nowISO() } },
    { new: true }
  ).lean();

  return updated;
}

async function removeItineraryItem(groupId, userId, itemId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const g = await TripGroup.findByIdAndUpdate(
    groupId,
    { $pull: { itinerary: { _id: toObjectId(itemId) } }, $set: { updatedAtISO: nowISO() } },
    { new: true }
  ).lean();

  const reindexed = reindexItinerary(g.itinerary || []);
  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $set: { itinerary: reindexed, updatedAtISO: nowISO() } },
    { new: true }
  ).lean();

  return updated;
}

async function reorderItinerary(groupId, userId, { itemId, toDayOffset, toSeq }) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const g = await TripGroup.findById(groupId).lean();
  if (!g) return null;

  const items = Array.isArray(g.itinerary) ? g.itinerary.map((x) => ({ ...x })) : [];
  const idx = items.findIndex((x) => String(x._id) === String(itemId));
  if (idx < 0) return null;

  const moving = items.splice(idx, 1);
  moving.dayOffset = toDayOffset;
  // Insert at approximate position, then reindex
  items.push(moving);
  let dayItems = items.filter((i) => i.dayOffset === toDayOffset);
  dayItems.sort((a, b) => (a.seq ?? 0) - (b.seq ?? 0));
  dayItems.forEach((i, index) => (i.seq = index));
  if (Number.isFinite(toSeq) && toSeq >= 0 && toSeq < dayItems.length) {
    // Ensure moving placed at desired seq
    const mIdx = dayItems.findIndex((i) => String(i._id) === String(moving._id));
    if (mIdx >= 0) {
      const m = dayItems.splice(mIdx, 1);
      dayItems.splice(toSeq, 0, m);
    }
  }

  const all = items
    .filter((i) => i.dayOffset !== toDayOffset)
    .concat(dayItems);
  const reindexed = reindexItinerary(all);

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $set: { itinerary: reindexed, updatedAtISO: nowISO() } },
    { new: true }
  ).lean();

  return updated;
}

// ---------- Expenses ----------
async function listExpenses(groupId, userId, { category, cursor, limit = 100 } = {}) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return { items: [], hasMore: false };

  const g = await TripGroup.findById(groupId).select({ 'budget.expenses': 1 }).lean();
  let items = Array.isArray(g?.budget?.expenses) ? [...g.budget.expenses] : [];

  if (category) items = items.filter((e) => e.category === category);
  items.sort((a, b) => new Date(b.occurredAtISO || 0) - new Date(a.occurredAtISO || 0));

  if (cursor) {
    items = items.filter((e) => String(e.occurredAtISO || '') < String(cursor));
  }

  const l = Math.min(coerceInt(limit, 100), 500);
  const page = items.slice(0, l);
  const hasMore = items.length > l;
  const nextCursor = hasMore ? page[page.length - 1].occurredAtISO || null : null;

  return { items: page, hasMore, nextCursor };
}

async function addExpense(groupId, userId, expense) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const e = {
    title: expense.title,
    amount: expense.amount,
    currency: expense.currency,
    category: expense.category || 'misc',
    paidBy: expense.paidBy ? toObjectId(expense.paidBy) : toObjectId(userId),
    split: expense.split || { type: 'equal', shares: [] },
    occurredAtISO: expense.occurredAtISO ? toISO(expense.occurredAtISO) : nowISO(),
    notes: expense.notes || null,
    createdBy: toObjectId(userId),
    updatedBy: toObjectId(userId)
  };

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $push: { 'budget.expenses': e }, $set: { updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

async function updateExpense(groupId, userId, expenseId, patch = {}) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const g = await TripGroup.findById(groupId).lean();
  const items = Array.isArray(g?.budget?.expenses) ? g.budget.expenses.map((x) => ({ ...x })) : [];
  const idx = items.findIndex((x) => String(x._id) === String(expenseId));
  if (idx < 0) return null;

  const e = items[idx];
  for (const k of ['title', 'amount', 'currency', 'category', 'paidBy', 'split', 'occurredAtISO', 'notes']) {
    if (patch[k] !== undefined) e[k] = k === 'paidBy' ? toObjectId(patch[k]) : patch[k];
  }
  e.updatedBy = toObjectId(userId);

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $set: { 'budget.expenses': items, updatedAtISO: nowISO() } },
    { new: true }
  ).lean();

  return updated;
}

async function removeExpense(groupId, userId, expenseId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $pull: { 'budget.expenses': { _id: toObjectId(expenseId) } }, $set: { updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

async function getExpenseSummary(groupId, userId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return { totals: [] };

  const g = await TripGroup.findById(groupId).select({ 'budget.expenses': 1, 'budget.baseCurrency': 1 }).lean();
  const expenses = Array.isArray(g?.budget?.expenses) ? g.budget.expenses : [];
  const byCurrency = new Map();
  for (const e of expenses) {
    const cur = e.currency || g.budget?.baseCurrency || 'INR';
    byCurrency.set(cur, (byCurrency.get(cur) || 0) + (e.amount || 0));
  }
  return { totals: Array.from(byCurrency.entries()).map(([currency, total]) => ({ currency, total })) };
}

// ---------- Checklist ----------
async function listChecklist(groupId, userId, { done, cursor, limit = 200 } = {}) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return { items: [], hasMore: false };

  const g = await TripGroup.findById(groupId).select({ checklist: 1 }).lean();
  let items = Array.isArray(g?.checklist) ? [...g.checklist] : [];

  if (typeof done === 'boolean') {
    items = items.filter((c) => !!c.done === done);
  }
  items.sort((a, b) => String(a.title).localeCompare(String(b.title)));

  if (cursor) {
    items = items.filter((c) => String(c._id) > String(cursor)); // simple pagination
  }

  const l = Math.min(coerceInt(limit, 200), 1000);
  const page = items.slice(0, l);
  const hasMore = items.length > l;
  const nextCursor = hasMore ? String(page[page.length - 1]._id) : null;

  return { items: page, hasMore, nextCursor };
}

async function addChecklistItem(groupId, userId, item) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const c = {
    title: item.title,
    done: !!item.done,
    dueISO: item.dueISO ? toISO(item.dueISO) : null,
    assignees: Array.isArray(item.assignees) ? item.assignees.map(toObjectId) : []
  };

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $push: { checklist: c }, $set: { updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

async function updateChecklistItem(groupId, userId, itemId, patch = {}) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const g = await TripGroup.findById(groupId).lean();
  const items = Array.isArray(g?.checklist) ? g.checklist.map((x) => ({ ...x })) : [];
  const idx = items.findIndex((x) => String(x._id) === String(itemId));
  if (idx < 0) return null;

  const c = items[idx];
  for (const k of ['title', 'done', 'dueISO']) {
    if (patch[k] !== undefined) c[k] = k === 'dueISO' ? toISO(patch[k]) : patch[k];
  }
  if (patch.assignees) c.assignees = patch.assignees.map(toObjectId);

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $set: { checklist: items, updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

async function removeChecklistItem(groupId, userId, itemId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $pull: { checklist: { _id: toObjectId(itemId) } }, $set: { updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

// ---------- Documents ----------
async function listDocuments(groupId, userId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return [];
  const g = await TripGroup.findById(groupId).select({ documents: 1 }).lean();
  return Array.isArray(g?.documents) ? g.documents : [];
}

async function addDocument(groupId, userId, doc) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const d = {
    key: doc.key,
    name: doc.name || null,
    mime: doc.mime || null,
    size: doc.size || null,
    url: doc.url || null
  };

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $push: { documents: d }, $set: { updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

async function removeDocument(groupId, userId, docId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return null;

  const updated = await TripGroup.findByIdAndUpdate(
    groupId,
    { $pull: { documents: { _id: toObjectId(docId) } }, $set: { updatedAtISO: nowISO() } },
    { new: true }
  ).lean();
  return updated;
}

// ---------- GeoJSON export (RFC 7946) ----------
async function getGroupGeoJSON(groupId, userId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return { type: 'FeatureCollection', features: [] };

  const g = await TripGroup.findById(groupId).select({ itinerary: 1, name: 1, slug: 1 }).lean();
  const items = Array.isArray(g?.itinerary) ? g.itinerary : [];

  const features = [];
  for (const it of items) {
    if (it.location?.type === 'Point' && Array.isArray(it.location.coordinates)) {
      features.push({
        type: 'Feature',
        geometry: it.location, // [lng, lat]
        properties: {
          title: it.title,
          type: it.type,
          dayOffset: it.dayOffset || 0,
          seq: it.seq || 0,
          startISO: it.startISO || null,
          endISO: it.endISO || null
        }
      });
    }
  }
  return { type: 'FeatureCollection', features };
}

// ---------- iCalendar export (RFC 5545) ----------
async function exportICal(groupId, userId) {
  const ok = await ensureMember(groupId, userId);
  if (!ok) return { filename: 'trip.ics', ics: '' };

  const g = await TripGroup.findById(groupId).select({ name: 1, itinerary: 1, settings: 1 }).lean();
  const name = g?.name || 'Trip';
  const items = Array.isArray(g?.itinerary) ? g.itinerary : [];

  const lines = [];
  lines.push('BEGIN:VCALENDAR');
  lines.push('VERSION:2.0');
  lines.push('PRODID:-//myapp//Planning//EN');

  for (const it of items) {
    // Only include timed items
    if (!it.startISO && !it.endISO) continue;
    const dtStart = it.startISO ? toICSDateUTC(it.startISO) : null;
    const dtEnd = it.endISO ? toICSDateUTC(it.endISO) : null;

    lines.push('BEGIN:VEVENT');
    if (dtStart) lines.push(`DTSTART:${dtStart}`);
    if (dtEnd) lines.push(`DTEND:${dtEnd}`);
    const summary = (it.title || it.type || 'Itinerary Item').replace(/\r?\n/g, ' ');
    lines.push(`SUMMARY:${summary}`);
    if (it.address?.city || it.address?.country) {
      const loc = [it.address.city, it.address.country].filter(Boolean).join(', ').replace(/\r?\n/g, ' ');
      if (loc) lines.push(`LOCATION:${loc}`);
    }
    if (it.notes) {
      const desc = String(it.notes).replace(/\r?\n/g, '\\n');
      lines.push(`DESCRIPTION:${desc}`);
    }
    lines.push('END:VEVENT');
  }

  lines.push('END:VCALENDAR');
  const ics = lines.join('\r\n'); // CRLF per RFC

  const filename = `${name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') || 'trip'}.ics`;
  return { filename, ics };
}

module.exports = {
  // Groups
  listGroups,
  createGroup,
  getGroupById,
  updateGroup,
  removeOrLeaveGroup,

  // Members & roles
  listMembers,
  addMembers,
  removeMembers,
  setRoles,

  // Itinerary
  listItinerary,
  addItineraryItem,
  updateItineraryItem,
  removeItineraryItem,
  reorderItinerary,

  // Expenses
  listExpenses,
  addExpense,
  updateExpense,
  removeExpense,
  getExpenseSummary,

  // Checklist
  listChecklist,
  addChecklistItem,
  updateChecklistItem,
  removeChecklistItem,

  // Documents
  listDocuments,
  addDocument,
  removeDocument,

  // Exports
  getGroupGeoJSON,
  exportICal
};
