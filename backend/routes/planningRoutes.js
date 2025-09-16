// C:\flutterapp\myapp\backend\routes\planningRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (planning is user-scoped)
const { requireAuth } = require('../middlewares/auth');

// Controllers (ensure these handlers exist)
const planningController = require('../controllers/planningController');          // high-level aggregations
const tripGroupsController = require('../controllers/tripGroupsController');      // TripGroup CRUD + subresources
const invitesController = require('../controllers/invitesController');            // Invite flows
const templatesController = require('../controllers/planningTemplatesController');// Template browse/apply

// Health
// GET /api/v1/planning/health
router.get('/health', (req, res) => res.json({ ok: true }));

/**
 * Trip Groups
 */

// List groups for current user (owner/member), filters and pagination
// GET /api/v1/planning/groups?cursor=&limit=&destination=&active=
router.get('/groups', requireAuth, tripGroupsController.listGroups);

// Create a group
// POST /api/v1/planning/groups
// Body: { name, cover?, settings:{ destination?, currency?, tz? }, startDate?, endDate? }
router.post('/groups', requireAuth, tripGroupsController.createGroup);

// Get group by id (includes summary aggregates)
 // GET /api/v1/planning/groups/:groupId
router.get('/groups/:groupId', requireAuth, tripGroupsController.getGroupById);

// Update group (name, cover, settings, dates)
 // PATCH /api/v1/planning/groups/:groupId
// Body: { name?, cover?, settings?, startDate?, endDate? }
router.patch('/groups/:groupId', requireAuth, tripGroupsController.updateGroup);

// Delete or leave group
// DELETE /api/v1/planning/groups/:groupId
router.delete('/groups/:groupId', requireAuth, tripGroupsController.removeOrLeaveGroup);

// Group GeoJSON (itinerary items as RFC 7946 FeatureCollection)
// GET /api/v1/planning/groups/:groupId/geojson
router.get('/groups/:groupId/geojson', requireAuth, tripGroupsController.getGroupGeoJSON);

// Export iCalendar (RFC 5545 .ics) for the group itinerary
// GET /api/v1/planning/groups/:groupId/ical
router.get('/groups/:groupId/ical', requireAuth, tripGroupsController.exportICal);

/**
 * Members and Roles
 */

// List members
// GET /api/v1/planning/groups/:groupId/members
router.get('/groups/:groupId/members', requireAuth, tripGroupsController.listMembers);

// Add members
// POST /api/v1/planning/groups/:groupId/members
// Body: { userIds: [] }
router.post('/groups/:groupId/members', requireAuth, tripGroupsController.addMembers);

// Remove members
// DELETE /api/v1/planning/groups/:groupId/members
// Body: { userIds: [] }
router.delete('/groups/:groupId/members', requireAuth, tripGroupsController.removeMembers);

// Set roles
// POST /api/v1/planning/groups/:groupId/roles
// Body: { roles: { [userId]: 'admin'|'member'|'viewer' } }
router.post('/groups/:groupId/roles', requireAuth, tripGroupsController.setRoles);

/**
 * Invites
 */

// Create invite(s) for emails
// POST /api/v1/planning/groups/:groupId/invites
// Body: { emails: [ ... ], role?: 'member'|'admin'|'viewer', message? }
router.post('/groups/:groupId/invites', requireAuth, invitesController.createInvites);

// List invites for a group
// GET /api/v1/planning/groups/:groupId/invites
router.get('/groups/:groupId/invites', requireAuth, invitesController.listInvites);

// Revoke invite
// POST /api/v1/planning/invites/:inviteId/revoke
router.post('/invites/:inviteId/revoke', requireAuth, invitesController.revokeInvite);

// Accept invite (by token; may be unauthenticated depending on flow)
// POST /api/v1/planning/invites/accept
// Body: { token }
router.post('/invites/accept', invitesController.acceptInvite);

/**
 * Itinerary Items
 */

// List items (supports dayOffset filter, tags)
// GET /api/v1/planning/groups/:groupId/itinerary?dayOffset=&tags=&cursor=&limit=
router.get('/groups/:groupId/itinerary', requireAuth, tripGroupsController.listItinerary);

// Add a new itinerary item
// POST /api/v1/planning/groups/:groupId/itinerary
// Body: { dayOffset, seq?, title, type?, entityType?, entityId?, startISO?, endISO?, durationMin?, location?, address?, notes?, tags?, photos?, meta? }
router.post('/groups/:groupId/itinerary', requireAuth, tripGroupsController.addItineraryItem);

// Update an item
// PATCH /api/v1/planning/groups/:groupId/itinerary/:itemId
router.patch('/groups/:groupId/itinerary/:itemId', requireAuth, tripGroupsController.updateItineraryItem);

// Delete an item
// DELETE /api/v1/planning/groups/:groupId/itinerary/:itemId
router.delete('/groups/:groupId/itinerary/:itemId', requireAuth, tripGroupsController.removeItineraryItem);

// Reorder items within a day or move across days
// POST /api/v1/planning/groups/:groupId/itinerary/reorder
// Body: { itemId, toDayOffset, toSeq }
router.post('/groups/:groupId/itinerary/reorder', requireAuth, tripGroupsController.reorderItinerary);

/**
 * Budget & Expenses
 */

// List expenses with filters and pagination
// GET /api/v1/planning/groups/:groupId/expenses?category=&cursor=&limit=
router.get('/groups/:groupId/expenses', requireAuth, tripGroupsController.listExpenses);

// Add expense
// POST /api/v1/planning/groups/:groupId/expenses
// Body: { title, amount, currency, category, paidBy?, split?, occurredAtISO?, notes? }
router.post('/groups/:groupId/expenses', requireAuth, tripGroupsController.addExpense);

// Update expense
// PATCH /api/v1/planning/groups/:groupId/expenses/:expenseId
router.patch('/groups/:groupId/expenses/:expenseId', requireAuth, tripGroupsController.updateExpense);

// Delete expense
// DELETE /api/v1/planning/groups/:groupId/expenses/:expenseId
router.delete('/groups/:groupId/expenses/:expenseId', requireAuth, tripGroupsController.removeExpense);

// Expense summary
// GET /api/v1/planning/groups/:groupId/expenses/summary
router.get('/groups/:groupId/expenses/summary', requireAuth, planningController.getExpenseSummary);

/**
 * Checklist
 */

// List checklist items
// GET /api/v1/planning/groups/:groupId/checklist?done=&cursor=&limit=
router.get('/groups/:groupId/checklist', requireAuth, tripGroupsController.listChecklist);

// Add checklist item
// POST /api/v1/planning/groups/:groupId/checklist
// Body: { title, dueISO?, assignees? }
router.post('/groups/:groupId/checklist', requireAuth, tripGroupsController.addChecklistItem);

// Update checklist item (toggle done, edit)
// PATCH /api/v1/planning/groups/:groupId/checklist/:itemId
router.patch('/groups/:groupId/checklist/:itemId', requireAuth, tripGroupsController.updateChecklistItem);

// Delete checklist item
// DELETE /api/v1/planning/groups/:groupId/checklist/:itemId
router.delete('/groups/:groupId/checklist/:itemId', requireAuth, tripGroupsController.removeChecklistItem);

/**
 * Documents
 */

// List documents
// GET /api/v1/planning/groups/:groupId/documents
router.get('/groups/:groupId/documents', requireAuth, tripGroupsController.listDocuments);

// Add a document record (upload handled elsewhere; this stores metadata)
// POST /api/v1/planning/groups/:groupId/documents
// Body: { key, name?, mime?, size?, url? }
router.post('/groups/:groupId/documents', requireAuth, tripGroupsController.addDocument);

// Delete a document record
// DELETE /api/v1/planning/groups/:groupId/documents/:docId
router.delete('/groups/:groupId/documents/:docId', requireAuth, tripGroupsController.removeDocument);

/**
 * Templates
 */

// Browse templates with search/facets
// GET /api/v1/planning/templates?destination=&tags=&themes=&cursor=&limit=
router.get('/templates', templatesController.listTemplates);

// Trending templates
// GET /api/v1/planning/templates/trending
router.get('/templates/trending', templatesController.getTrendingTemplates);

// Template details
// GET /api/v1/planning/templates/:templateId
router.get('/templates/:templateId', templatesController.getTemplateById);

// Template GeoJSON (items as RFC 7946 points)
// GET /api/v1/planning/templates/:templateId/geojson
router.get('/templates/:templateId/geojson', templatesController.getTemplateGeoJSON);

// Create template (auth required)
// POST /api/v1/planning/templates
// Body: { name, description?, cover?, destination?, tags?, themes?, days:[{...}] }
router.post('/templates', requireAuth, templatesController.createTemplate);

// Update template
// PATCH /api/v1/planning/templates/:templateId
router.patch('/templates/:templateId', requireAuth, templatesController.updateTemplate);

// Delete template
// DELETE /api/v1/planning/templates/:templateId
router.delete('/templates/:templateId', requireAuth, templatesController.deleteTemplate);

// Apply template to a group (append or create new group)
// POST /api/v1/planning/templates/:templateId/apply
// Body: { groupId? (if omitted, create new), options?: { mergeStrategy:'append'|'replace', startDate? } }
router.post('/templates/:templateId/apply', requireAuth, templatesController.applyTemplateToGroup);

module.exports = router;
