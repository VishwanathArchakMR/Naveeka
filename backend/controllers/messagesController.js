// C:\flutterapp\myapp\backend\controllers\messagesController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const MessageThread = require('../models/MessageThread'); // { type: 'dm'|'group', participants: [userId], title, icon, lastMessageAt, createdBy }
const Message = require('../models/Message');             // { threadId, senderId, type, text, attachments[], location(Point), replyTo, reactions[], editedAt, deletedAt }
const ReadReceipt = require('../models/ReadReceipt');     // { threadId, userId, lastReadMessageId, lastReadAt }
const User = require('../models/user');                   // minimal lookup for names/avatars
const Place = require('../models/Place');                 // for suggested places in chats

// Services
const messageService = require('../services/messageService');     // fanout/websocket, typing, delivery
const storageService = require('../services/storageService');     // signed URLs for media
const cacheService = require('../services/cacheService');         // recent lists, typing state
const locationService = require('../services/locationService');   // distance calculation (km)

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601 UTC
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const isNonEmpty = (s) => typeof s === 'string' && s.trim().length > 0;

// Build cursor/pagination utility
function buildCursorQuery({ before, after }) {
  // Use createdAt cursor pagination for stable ordering
  const q = {};
  if (before) q.createdAt = { $lt: new Date(before) };
  if (after) q.createdAt = { $gt: new Date(after) };
  return q;
}

// GET /api/v1/messages/threads?type=dm|group&q=&page=&limit=
exports.getThreads = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { type, q, page = 1, limit = 20 } = req.query;
  const p = clamp(parseInt(page || 1), 1, 200);
  const l = clamp(parseInt(limit || 20), 1, 100);
  const skip = (p - 1) * l;

  const filter = { participants: userId };
  if (type) filter.type = type;
  if (q && String(q).trim().length >= 2) {
    filter.$or = [
      { title: new RegExp(q, 'i') },
      { 'metadata.keywords': new RegExp(q, 'i') }
    ];
  }

  const [threads, total] = await Promise.all([
    MessageThread.find(filter)
      .sort({ lastMessageAt: -1 })
      .skip(skip)
      .limit(l)
      .select('type participants title icon lastMessageAt createdBy createdAt updatedAt')
      .lean(),
    MessageThread.countDocuments(filter)
  ]);

  // Unread counts and last message preview
  const threadIds = threads.map((t) => t._id);
  const lastMessages = await Message.aggregate([
    { $match: { threadId: { $in: threadIds } } },
    { $sort: { createdAt: -1 } },
    { $group: { _id: '$threadId', msg: { $first: '$$ROOT' } } }
  ]);
  const lastMap = lastMessages.reduce((m, r) => (m[String(r._id)] = r.msg, m), {});

  const receipts = await ReadReceipt.find({ threadId: { $in: threadIds }, userId }).select('threadId lastReadMessageId').lean();
  const readMap = receipts.reduce((m, r) => (m[String(r.threadId)] = r.lastReadMessageId, m), {});

  const unreadCounts = await Message.aggregate([
    { $match: { threadId: { $in: threadIds } } },
    {
      $group: {
        _id: '$threadId',
        total: { $sum: 1 },
        messages: { $push: '$_id' }
      }
    }
  ]);

  const unreadMap = {};
  for (const r of unreadCounts) {
    const lastReadId = readMap[String(r._id)];
    if (!lastReadId) {
      unreadMap[String(r._id)] = r.total;
    } else {
      const idx = r.messages.findIndex((id) => String(id) === String(lastReadId));
      unreadMap[String(r._id)] = idx === -1 ? r.total : r.total - (idx + 1);
    }
  }

  const items = threads.map((t) => {
    const preview = lastMap[String(t._id)];
    return {
      ...t,
      lastMessage: preview
        ? {
            id: preview._id,
            type: preview.type,
            text: preview.type === 'text' ? preview.text : null,
            senderId: preview.senderId,
            createdAt: preview.createdAt
          }
        : null,
      unreadCount: unreadMap[String(t._id)] || 0
    };
  });

  const totalPages = Math.ceil(total / l);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Threads fetched', {
      threads: items,
      pagination: { currentPage: p, totalPages, totalCount: total, limit: l, hasNextPage: p < totalPages, hasPrevPage: p > 1 },
      generatedAt: toISO()
    })
  );
});

// POST /api/v1/messages/threads
// Body: { type: 'dm'|'group', participants: [userId], title?, icon? }
exports.createThread = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { type = 'dm', participants = [], title, icon } = req.body || {};
  const unique = Array.from(new Set([userId, ...participants.map(String)]));

  if (type === 'dm' && unique.length !== 2) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'DM threads must include exactly two participants');
  }

  // Idempotent DM: reuse existing
  if (type === 'dm') {
    const existing = await MessageThread.findOne({ type: 'dm', participants: { $all: unique, $size: 2 } }).lean();
    if (existing) {
      return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Thread exists', { thread: existing, generatedAt: toISO() }));
    }
  }

  const thread = await MessageThread.create({
    type,
    participants: unique,
    title: type === 'group' ? title || 'New Group' : undefined,
    icon: type === 'group' ? icon : undefined,
    createdBy: userId,
    lastMessageAt: new Date()
  });

  // Notify via real-time channel
  messageService.notifyThreadCreated(thread).catch(() => {});

  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Thread created', { thread, generatedAt: toISO() }));
});

// GET /api/v1/messages/threads/:id
exports.getThreadById = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;

  const thread = await MessageThread.findById(id).lean();
  if (!thread || !thread.participants.map(String).includes(String(userId))) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');
  }

  // Minimal participant profiles
  const users = await User.find({ _id: { $in: thread.participants } }).select('name avatar').lean();
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Thread fetched', { thread, participants: users, generatedAt: toISO() }));
});

// GET /api/v1/messages/threads/:id/messages?before=&after=&limit=
exports.getThreadMessages = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { before, after, limit = 50 } = req.query;

  const thread = await MessageThread.findById(id).lean();
  if (!thread || !thread.participants.map(String).includes(String(userId))) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');
  }

  const l = clamp(parseInt(limit || 50), 1, 200);
  const cursor = buildCursorQuery({ before, after });

  const rows = await Message.find({ threadId: id, ...cursor })
    .sort({ createdAt: -1 })
    .limit(l)
    .lean();

  // Attach geoUri to location messages
  const messages = rows.map((m) => {
    if (m.type === 'location' && m?.location?.coordinates) {
      const [lng, lat] = m.location.coordinates;
      return { ...m, geoUri: `geo:${lat},${lng}` };
    }
    return m;
  });

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Messages fetched', { messages, generatedAt: toISO() }));
});

// POST /api/v1/messages/threads/:id/messages
// Body: { type: 'text'|'image'|'video'|'audio'|'file'|'location', text?, attachments?, location?:{lat,lng}, replyTo? }
exports.sendMessage = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { type = 'text', text, attachments = [], location, replyTo } = req.body || {};

  const thread = await MessageThread.findById(id).lean();
  if (!thread || !thread.participants.map(String).includes(String(userId))) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');
  }

  if (type === 'text' && !isNonEmpty(text)) {
    throw new ApiError(StatusCodes.BAD_REQUEST, 'Text cannot be empty');
  }

  let locPoint = null;
  if (type === 'location') {
    if (!location || Number.isNaN(parseFloat(location.lat)) || Number.isNaN(parseFloat(location.lng))) {
      throw new ApiError(StatusCodes.BAD_REQUEST, 'Valid location (lat,lng) is required');
    }
    // RFC 7946-compatible position order in Point geometry: [lng, lat]
    locPoint = { type: 'Point', coordinates: [parseFloat(location.lng), parseFloat(location.lat)] };
  }

  // Sign attachments (if client sent file keys needing signed URLs)
  const signed = [];
  for (const att of attachments) {
    // att: { key, mime, size, name }
    const url = await storageService.getSignedUrl(att.key).catch(() => null);
    signed.push({ ...att, url });
  }

  const msg = await Message.create({
    threadId: id,
    senderId: userId,
    type,
    text: type === 'text' ? text : undefined,
    attachments: signed,
    location: locPoint,
    replyTo: replyTo || null
  });

  // Update thread lastMessageAt
  await MessageThread.findByIdAndUpdate(id, { $set: { lastMessageAt: new Date() } }).catch(() => {});

  // Push real-time event (WebSocket)
  messageService.notifyMessageCreated({ threadId: id, message: msg }).catch(() => {});

  // Build response with geoUri when location
  const out = msg.toObject();
  if (type === 'location' && locPoint?.coordinates) {
    out.geoUri = `geo:${locPoint.coordinates},${locPoint.coordinates}`;
  }

  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Message sent', { message: out, generatedAt: toISO() }));
});

// POST /api/v1/messages/threads/:id/read
// Body: { lastReadMessageId }
exports.markRead = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { lastReadMessageId } = req.body || {};

  const thread = await MessageThread.findById(id).lean();
  if (!thread || !thread.participants.map(String).includes(String(userId))) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');
  }

  if (!lastReadMessageId) throw new ApiError(StatusCodes.BAD_REQUEST, 'lastReadMessageId is required');

  const receipt = await ReadReceipt.findOneAndUpdate(
    { threadId: id, userId },
    { $set: { lastReadMessageId, lastReadAt: new Date() } },
    { upsert: true, new: true }
  ).lean();

  // Real-time notify for read receipts
  messageService.notifyReadReceipt({ threadId: id, userId, lastReadMessageId }).catch(() => {});

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Read receipt updated', { receipt, generatedAt: toISO() }));
});

// POST /api/v1/messages/threads/:id/typing
// Body: { typing: true|false }
exports.setTyping = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { typing } = req.body || {};

  const thread = await MessageThread.findById(id).lean();
  if (!thread || !thread.participants.map(String).includes(String(userId))) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');
  }

  await messageService.setTypingStatus({ threadId: id, userId, typing: !!typing });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Typing status updated', { typing: !!typing, generatedAt: toISO() }));
});

// POST /api/v1/messages/threads/:id/messages/:messageId/reactions
// Body: { emoji } -> toggle reaction for current user
exports.toggleReaction = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, messageId } = req.params;
  const { emoji } = req.body || {};
  if (!emoji) throw new ApiError(StatusCodes.BAD_REQUEST, 'emoji is required');

  const thread = await MessageThread.findById(id).lean();
  if (!thread || !thread.participants.map(String).includes(String(userId))) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');
  }

  const msg = await Message.findOne({ _id: messageId, threadId: id }).lean();
  if (!msg) throw new ApiError(StatusCodes.NOT_FOUND, 'Message not found');

  const existing = await Message.findOne({ _id: messageId, 'reactions.userId': userId, 'reactions.emoji': emoji }).lean();

  if (existing) {
    await Message.updateOne({ _id: messageId }, { $pull: { reactions: { userId, emoji } } });
  } else {
    await Message.updateOne({ _id: messageId }, { $push: { reactions: { userId, emoji, at: new Date() } } });
  }

  messageService.notifyReaction({ threadId: id, messageId, emoji, userId }).catch(() => {});
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Reaction toggled', { messageId, emoji, generatedAt: toISO() }));
});

// PUT /api/v1/messages/threads/:id/messages/:messageId
// Body: { text }
exports.editMessage = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, messageId } = req.params;
  const { text } = req.body || {};

  const msg = await Message.findOne({ _id: messageId, threadId: id }).lean();
  if (!msg) throw new ApiError(StatusCodes.NOT_FOUND, 'Message not found');
  if (String(msg.senderId) !== String(userId)) throw new ApiError(StatusCodes.FORBIDDEN, 'Cannot edit others’ messages');

  if (!isNonEmpty(text)) throw new ApiError(StatusCodes.BAD_REQUEST, 'Text cannot be empty');

  await Message.updateOne({ _id: messageId }, { $set: { text, editedAt: new Date() } });
  messageService.notifyMessageEdited({ threadId: id, messageId, text }).catch(() => {});
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Message edited', { messageId, generatedAt: toISO() }));
});

// DELETE /api/v1/messages/threads/:id/messages/:messageId
exports.deleteMessage = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, messageId } = req.params;

  const msg = await Message.findOne({ _id: messageId, threadId: id }).lean();
  if (!msg) throw new ApiError(StatusCodes.NOT_FOUND, 'Message not found');
  if (String(msg.senderId) !== String(userId)) throw new ApiError(StatusCodes.FORBIDDEN, 'Cannot delete others’ messages');

  await Message.updateOne({ _id: messageId }, { $set: { deletedAt: new Date(), text: null, attachments: [], location: null } });
  messageService.notifyMessageDeleted({ threadId: id, messageId }).catch(() => {});
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Message deleted', { messageId, generatedAt: toISO() }));
});

// GET /api/v1/messages/recent?limit=
exports.getRecent = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');
  const { limit = 10 } = req.query;
  const l = clamp(parseInt(limit), 1, 50);

  const cacheKey = `messages:recent:${userId}:${l}`;
  const cached = await cacheService?.get?.(cacheKey);
  if (cached) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Recent threads (cache)', cached));
  }

  const threads = await MessageThread.find({ participants: userId })
    .sort({ lastMessageAt: -1 })
    .limit(l)
    .select('type participants title icon lastMessageAt')
    .lean();

  const payload = { threads, generatedAt: toISO() };
  await cacheService?.set?.(cacheKey, payload, 60);
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Recent threads', payload));
});

// GET /api/v1/messages/suggestions/places?lat=&lng=&radius=&limit=
exports.suggestPlacesToShare = asyncHandler(async (req, res) => {
  const { lat, lng, radius = 25, limit = 8 } = req.query;
  if (!lat || !lng) {
    return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions: [] }));
  }

  const rows = await Place.find({
    location: {
      $near: {
        $geometry: { type: 'Point', coordinates: [parseFloat(lng), parseFloat(lat)] },
        $maxDistance: Number(radius) * 1000
      }
    }
  })
    .limit(clamp(parseInt(limit), 1, 20))
    .select('name city country location rating')
    .lean();

  const suggestions = rows.map((p) => {
    const [lngP, latP] = p.location.coordinates;
    const distKm = locationService.calculateDistance(parseFloat(lat), parseFloat(lng), latP, lngP);
    return {
      id: p._id,
      name: p.name,
      city: p.city || null,
      country: p.country || null,
      rating: p.rating?.score || null,
      distance: Math.round(distKm * 100) / 100,
      distanceUnit: 'km',
      geoUri: `geo:${latP},${lngP}`
    };
  });

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions, generatedAt: toISO() }));
});

// GET /api/v1/messages/threads/:id/geojson
// Emits RFC 7946 FeatureCollection for last N location messages to overlay in chat map view
exports.getThreadGeoJSON = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { limit = 100 } = req.query;

  const thread = await MessageThread.findById(id).lean();
  if (!thread || !thread.participants.map(String).includes(String(userId))) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');
  }

  const rows = await Message.find({ threadId: id, type: 'location', location: { $ne: null } })
    .sort({ createdAt: -1 })
    .limit(clamp(parseInt(limit), 1, 500))
    .select('senderId createdAt location')
    .lean();

  const features = rows
    .filter((m) => m?.location?.coordinates && Array.isArray(m.location.coordinates))
    .map((m) => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: m.location.coordinates }, // [lng,lat]
      properties: { senderId: m.senderId, createdAt: m.createdAt, geo: `geo:${m.location.coordinates},${m.location.coordinates}` }
    }));

  const fc = { type: 'FeatureCollection', features, generatedAt: toISO() };
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json(fc);
});
