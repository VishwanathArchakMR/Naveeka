// C:\flutterapp\myapp\backend\controllers\planningController.js

const { StatusCodes } = require('http-status-codes');
const { ApiError } = require('../utils/ApiError');
const { ApiResponse } = require('../utils/ApiResponse');
const { asyncHandler } = require('../utils/asyncHandler');

// Models
const TripGroup = require('../models/TripGroup');               // { name, cover, ownerId, members[], roles, itinerary[], budget{}, checklist[], documents[], invites[], settings{} }
const PlanningTemplate = require('../models/PlanningTemplate'); // { name, description, days[], tags[], cover, authorId, isPublic }
const Invite = require('../models/Invite');                     // { groupId, inviterId, inviteeEmail, token, role, status, expiresAt }
const Place = require('../models/Place');
const Hotel = require('../models/Hotel');
const Activity = require('../models/Activity');
const Airport = require('../models/Airport');

// Services
const planningService = require('../services/planningService');   // business logic: apply templates, ICS export, totals
const mapService = require('../services/mapService');             // RFC 7946 helpers for routes/points
const storageService = require('../services/storageService');     // signed URLs for docs
const cacheService = require('../services/cacheService');         // optional caching
const locationService = require('../services/locationService');   // distance calculations
const aiService = require('../services/aiService');               // smart suggestions (optional)

// Helpers
const toISO = (d = new Date()) => d.toISOString(); // ISO 8601
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const parseCSV = (v) => (v ? String(v).split(',').map((s) => s.trim()).filter(Boolean) : []);

// Authorization helpers
function assertMemberOrThrow(group, userId) {
  if (!group.members.map(String).includes(String(userId)) && String(group.ownerId) !== String(userId)) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Access denied');
  }
}
function assertOwnerOrAdminOrThrow(group, userId) {
  const isOwner = String(group.ownerId) === String(userId);
  const role = (group.roles || {})[String(userId)];
  const isAdmin = role === 'admin';
  if (!isOwner && !isAdmin) throw new ApiError(StatusCodes.FORBIDDEN, 'Admin or owner required');
}

// GET /api/v1/planning/groups?query=&page=&limit=
exports.getGroups = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');

  const { query, page = 1, limit = 20 } = req.query;
  const p = clamp(parseInt(page), 1, 200);
  const l = clamp(parseInt(limit), 1, 100);
  const skip = (p - 1) * l;

  const filter = {
    $or: [{ ownerId: userId }, { members: userId }]
  };
  if (query && query.trim().length >= 2) {
    filter.$and = [
      {
        $or: [
          { name: new RegExp(query, 'i') },
          { 'settings.destination': new RegExp(query, 'i') }
        ]
      }
    ];
  }

  const [rows, total] = await Promise.all([
    TripGroup.find(filter)
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(l)
      .select('name cover ownerId members settings startDate endDate updatedAt createdAt')
      .lean(),
    TripGroup.countDocuments(filter)
  ]);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Groups fetched', {
      groups: rows,
      pagination: {
        currentPage: p,
        totalPages: Math.ceil(total / l),
        totalCount: total,
        limit: l,
        hasNextPage: p * l < total,
        hasPrevPage: p > 1
      },
      generatedAt: toISO()
    })
  );
});

// POST /api/v1/planning/groups
// Body: { name, cover?, startDate?, endDate?, settings? }
exports.createGroup = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  if (!userId) throw new ApiError(StatusCodes.UNAUTHORIZED, 'Unauthorized');
  const { name, cover, startDate, endDate, settings } = req.body || {};
  if (!name) throw new ApiError(StatusCodes.BAD_REQUEST, 'name is required');

  const group = await TripGroup.create({
    name,
    cover,
    ownerId: userId,
    members: [userId],
    roles: { [String(userId)]: 'admin' },
    startDate: startDate ? new Date(startDate) : null,
    endDate: endDate ? new Date(endDate) : null,
    settings: settings || {}
  });

  return res.status(StatusCodes.CREATED).json(
    new ApiResponse(StatusCodes.CREATED, 'Group created', { group, generatedAt: toISO() })
  );
});

// GET /api/v1/planning/groups/:id
exports.getGroupById = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Group fetched', { group, generatedAt: toISO() })
  );
});

// PUT /api/v1/planning/groups/:id
// Body: { name?, cover?, startDate?, endDate?, settings? }
exports.updateGroup = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertOwnerOrAdminOrThrow(group, userId);

  const patch = req.body || {};
  if (patch.startDate) patch.startDate = new Date(patch.startDate);
  if (patch.endDate) patch.endDate = new Date(patch.endDate);

  const updated = await TripGroup.findByIdAndUpdate(id, { $set: patch }, { new: true }).lean();

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Group updated', { group: updated, generatedAt: toISO() })
  );
});

// DELETE /api/v1/planning/groups/:id
exports.deleteGroup = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  if (String(group.ownerId) !== String(userId)) {
    throw new ApiError(StatusCodes.FORBIDDEN, 'Only owner can delete group');
  }

  await TripGroup.deleteOne({ _id: id });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Group deleted', { id, generatedAt: toISO() }));
});

// POST /api/v1/planning/groups/:id/invite
// Body: { inviteeEmail, role='member' }
exports.inviteMember = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { inviteeEmail, role = 'member' } = req.body || {};

  if (!inviteeEmail) throw new ApiError(StatusCodes.BAD_REQUEST, 'inviteeEmail is required');

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertOwnerOrAdminOrThrow(group, userId);

  const invite = await planningService.createInvite({ groupId: id, inviterId: userId, inviteeEmail, role });
  return res.status(StatusCodes.CREATED).json(
    new ApiResponse(StatusCodes.CREATED, 'Invite created', { invite, generatedAt: toISO() })
  );
});

// POST /api/v1/planning/groups/:id/join
// Body: { token }
exports.joinGroup = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { token } = req.body || {};
  if (!token) throw new ApiError(StatusCodes.BAD_REQUEST, 'token is required');

  const result = await planningService.consumeInvite({ groupId: id, token, userId });
  if (!result?.success) throw new ApiError(StatusCodes.BAD_REQUEST, result?.message || 'Unable to join group');

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Joined group', { groupId: id, generatedAt: toISO() }));
});

// POST /api/v1/planning/groups/:id/leave
exports.leaveGroup = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;

  const updated = await planningService.leaveGroup({ groupId: id, userId });
  if (!updated) throw new ApiError(StatusCodes.BAD_REQUEST, 'Unable to leave group');

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Left group', { groupId: id, generatedAt: toISO() }));
});

// GET /api/v1/planning/templates?query=&tags=&page=&limit=
exports.getTemplates = asyncHandler(async (req, res) => {
  const { query, tags, page = 1, limit = 20 } = req.query;
  const p = clamp(parseInt(page), 1, 200);
  const l = clamp(parseInt(limit), 1, 100);
  const skip = (p - 1) * l;

  const tagArr = parseCSV(tags);
  const filter = { isPublic: true };
  if (query && query.trim().length >= 2) {
    filter.$or = [{ name: new RegExp(query, 'i') }, { description: new RegExp(query, 'i') }, { tags: new RegExp(query, 'i') }];
  }
  if (tagArr.length) filter.tags = { $in: tagArr };

  const [rows, total] = await Promise.all([
    PlanningTemplate.find(filter).sort({ updatedAt: -1 }).skip(skip).limit(l).lean(),
    PlanningTemplate.countDocuments(filter)
  ]);

  return res.status(StatusCodes.OK).json(
    new ApiResponse(StatusCodes.OK, 'Templates fetched', {
      templates: rows,
      pagination: { currentPage: p, totalPages: Math.ceil(total / l), totalCount: total, limit: l, hasNextPage: p * l < total, hasPrevPage: p > 1 },
      generatedAt: toISO()
    })
  );
});

// POST /api/v1/planning/templates
// Body: { name, description, days[], tags[], cover? }
exports.createTemplate = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const payload = req.body || {};
  if (!payload.name || !Array.isArray(payload.days)) throw new ApiError(StatusCodes.BAD_REQUEST, 'name and days are required');

  const template = await PlanningTemplate.create({ ...payload, authorId: userId, isPublic: !!payload.isPublic });
  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Template created', { template, generatedAt: toISO() }));
});

// POST /api/v1/planning/groups/:id/apply-template
// Body: { templateId, mode='append'|'replace' }
exports.applyTemplateToGroup = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { templateId, mode = 'append' } = req.body || {};

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertOwnerOrAdminOrThrow(group, userId);

  const updated = await planningService.applyTemplate({ groupId: id, templateId, mode });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Template applied', { group: updated, generatedAt: toISO() }));
});

// GET /api/v1/planning/groups/:id/itinerary?dayOffset=&limit=
exports.getItinerary = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { dayOffset = 0, limit = 200 } = req.query;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const items = await planningService.getItinerary({ groupId: id, dayOffset: parseInt(dayOffset), limit: clamp(parseInt(limit), 1, 1000) });

  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Itinerary fetched', { items, generatedAt: toISO() }));
});

// POST /api/v1/planning/groups/:id/itinerary/items
// Body: { title, startISO, endISO, type, entityType?, entityId?, notes?, location?:{lat,lng}, meta? }
exports.addItineraryItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const payload = req.body || {};
  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertOwnerOrAdminOrThrow(group, userId);

  // Normalize location to RFC 7946 Point [lng,lat]
  let loc = null;
  if (payload.location && payload.location.lat != null && payload.location.lng != null) {
    loc = { type: 'Point', coordinates: [parseFloat(payload.location.lng), parseFloat(payload.location.lat)] };
  }

  const created = await planningService.addItineraryItem({ groupId: id, ...payload, location: loc });
  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Itinerary item added', { item: created, generatedAt: toISO() }));
});

// PUT /api/v1/planning/groups/:id/itinerary/items/:itemId
exports.updateItineraryItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, itemId } = req.params;
  const patch = req.body || {};
  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertOwnerOrAdminOrThrow(group, userId);

  if (patch.location && patch.location.lat != null && patch.location.lng != null) {
    patch.location = { type: 'Point', coordinates: [parseFloat(patch.location.lng), parseFloat(patch.location.lat)] };
  }

  const updated = await planningService.updateItineraryItem({ groupId: id, itemId, patch });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Itinerary item updated', { item: updated, generatedAt: toISO() }));
});

// DELETE /api/v1/planning/groups/:id/itinerary/items/:itemId
exports.removeItineraryItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, itemId } = req.params;
  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertOwnerOrAdminOrThrow(group, userId);

  await planningService.removeItineraryItem({ groupId: id, itemId });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Itinerary item removed', { itemId, generatedAt: toISO() }));
});

// POST /api/v1/planning/groups/:id/itinerary/reorder
// Body: { orderedItemIds: [] }
exports.reorderItineraryItems = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { orderedItemIds } = req.body || {};
  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertOwnerOrAdminOrThrow(group, userId);

  const items = await planningService.reorderItinerary({ groupId: id, orderedItemIds });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Itinerary reordered', { items, generatedAt: toISO() }));
});

// GET /api/v1/planning/groups/:id/itinerary/geojson
// Emits RFC 7946 FeatureCollection of itinerary POIs and optional route lines
exports.getItineraryGeoJSON = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const fc = await planningService.getItineraryGeoJSON({ groupId: id });
  res.setHeader('Content-Type', 'application/geo+json');
  return res.status(StatusCodes.OK).json({ ...fc, generatedAt: toISO() });
});

// GET /api/v1/planning/groups/:id/export/ics
// Exports iCalendar (RFC 5545) of itinerary events
exports.exportICS = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const icsText = await planningService.exportICS({ groupId: id }); // text/calendar per RFC 5545
  res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="trip-${id}.ics"`);
  return res.status(StatusCodes.OK).send(icsText);
});

// GET /api/v1/planning/groups/:id/budget
exports.getBudget = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const budget = await planningService.getBudget({ groupId: id });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Budget fetched', { budget, generatedAt: toISO() }));
});

// POST /api/v1/planning/groups/:id/budget/expenses
// Body: { title, amount, currency, category, paidBy, split:{ type, shares? }, occurredAtISO }
exports.addExpense = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const payload = req.body || {};

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const expense = await planningService.addExpense({ groupId: id, ...payload, createdBy: userId });
  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Expense added', { expense, generatedAt: toISO() }));
});

// PUT /api/v1/planning/groups/:id/budget/expenses/:expenseId
exports.updateExpense = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, expenseId } = req.params;
  const patch = req.body || {};

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const expense = await planningService.updateExpense({ groupId: id, expenseId, patch, updatedBy: userId });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Expense updated', { expense, generatedAt: toISO() }));
});

// DELETE /api/v1/planning/groups/:id/budget/expenses/:expenseId
exports.removeExpense = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, expenseId } = req.params;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  await planningService.removeExpense({ groupId: id, expenseId, removedBy: userId });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Expense removed', { expenseId, generatedAt: toISO() }));
});

// GET /api/v1/planning/groups/:id/checklist
exports.getChecklist = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const checklist = await planningService.getChecklist({ groupId: id });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Checklist fetched', { checklist, generatedAt: toISO() }));
});

// POST /api/v1/planning/groups/:id/checklist
// Body: { title, dueISO?, assignees?[] }
exports.addChecklistItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const payload = req.body || {};

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const item = await planningService.addChecklistItem({ groupId: id, ...payload, createdBy: userId });
  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Checklist item added', { item, generatedAt: toISO() }));
});

// PUT /api/v1/planning/groups/:id/checklist/:itemId
exports.updateChecklistItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, itemId } = req.params;
  const patch = req.body || {};

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const item = await planningService.updateChecklistItem({ groupId: id, itemId, patch, updatedBy: userId });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Checklist item updated', { item, generatedAt: toISO() }));
});

// DELETE /api/v1/planning/groups/:id/checklist/:itemId
exports.removeChecklistItem = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, itemId } = req.params;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  await planningService.removeChecklistItem({ groupId: id, itemId, removedBy: userId });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Checklist item removed', { itemId, generatedAt: toISO() }));
});

// POST /api/v1/planning/groups/:id/documents/upload
// Body: { key, name, mime, size }
exports.uploadDocument = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { key, name, mime, size } = req.body || {};

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const url = await storageService.getSignedUrl(key);
  const doc = await planningService.addDocument({ groupId: id, doc: { key, name, mime, size, url, uploadedBy: userId } });
  return res.status(StatusCodes.CREATED).json(new ApiResponse(StatusCodes.CREATED, 'Document uploaded', { document: doc, generatedAt: toISO() }));
});

// DELETE /api/v1/planning/groups/:id/documents/:docId
exports.removeDocument = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id, docId } = req.params;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  await planningService.removeDocument({ groupId: id, docId, userId });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Document removed', { docId, generatedAt: toISO() }));
});

// GET /api/v1/planning/groups/:id/suggestions?focus=day|place|food&limit=10
exports.getSuggestions = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  const { focus = 'day', limit = 10 } = req.query;

  const group = await TripGroup.findById(id).lean();
  if (!group) throw new ApiError(StatusCodes.NOT_FOUND, 'Group not found');
  assertMemberOrThrow(group, userId);

  const suggestions = await aiService.getPlanningSuggestions({ group, focus, limit: clamp(parseInt(limit), 1, 25) });
  return res.status(StatusCodes.OK).json(new ApiResponse(StatusCodes.OK, 'Suggestions fetched', { suggestions, generatedAt: toISO() }));
});
