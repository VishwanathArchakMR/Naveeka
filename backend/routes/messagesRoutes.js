// C:\flutterapp\myapp\backend\routes\messagesRoutes.js

const express = require('express');
const router = express.Router();

// Auth middleware (all messaging routes are user-scoped)
const { requireAuth } = require('../middlewares/auth');

// Controllers (ensure these files export the referenced handlers)
const threadsController = require('../controllers/messageThreadsController');
const messagesController = require('../controllers/messagesController');
const receiptsController = require('../controllers/readReceiptsController');

// Health
// GET /api/v1/messages/health
router.get('/health', (req, res) => res.json({ ok: true }));

/**
 * Threads
 */

// List threads for the current user with cursor pagination and filters
// GET /api/v1/messages/threads?type=dm|group&muted=&archived=&pinned=&cursor=&limit=
router.get('/threads', requireAuth, threadsController.listThreads);

// Create thread (dm or group)
// POST /api/v1/messages/threads
// Body: { type:'dm'|'group', participants:[userId,...], title?, icon?, description? }
router.post('/threads', requireAuth, threadsController.createThread);

// Get a thread by id with last message metadata
// GET /api/v1/messages/threads/:id
router.get('/threads/:id', requireAuth, threadsController.getThreadById);

// Update a thread (title/icon/description/roles)
// PATCH /api/v1/messages/threads/:id
// Body: { title?, icon?, description?, roles? }
router.patch('/threads/:id', requireAuth, threadsController.updateThread);

// Add members to a group thread
// POST /api/v1/messages/threads/:id/members
// Body: { userIds: [ ... ] }
router.post('/threads/:id/members', requireAuth, threadsController.addMembers);

// Remove members from a group thread
// DELETE /api/v1/messages/threads/:id/members
// Body: { userIds: [ ... ] }
router.delete('/threads/:id/members', requireAuth, threadsController.removeMembers);

// Mute/unmute thread for current user
// POST /api/v1/messages/threads/:id/mute
router.post('/threads/:id/mute', requireAuth, threadsController.muteThread);
// POST /api/v1/messages/threads/:id/unmute
router.post('/threads/:id/unmute', requireAuth, threadsController.unmuteThread);

// Archive/unarchive thread for current user
// POST /api/v1/messages/threads/:id/archive
router.post('/threads/:id/archive', requireAuth, threadsController.archiveThread);
// POST /api/v1/messages/threads/:id/unarchive
router.post('/threads/:id/unarchive', requireAuth, threadsController.unarchiveThread);

// Pin/unpin thread for current user
// POST /api/v1/messages/threads/:id/pin
router.post('/threads/:id/pin', requireAuth, threadsController.pinThread);
// POST /api/v1/messages/threads/:id/unpin
router.post('/threads/:id/unpin', requireAuth, threadsController.unpinThread);

// Read receipts list for a thread
// GET /api/v1/messages/threads/:id/read-receipts
router.get('/threads/:id/read-receipts', requireAuth, receiptsController.getThreadReceipts);

// Mark thread as read up to a message
// POST /api/v1/messages/threads/:id/read
// Body: { messageId, at?: ISODateString }
router.post('/threads/:id/read', requireAuth, receiptsController.markRead);

// Stream live thread events via SSE (optional; ensure controller sets proper headers)
// GET /api/v1/messages/threads/:id/stream
router.get('/threads/:id/stream', requireAuth, threadsController.streamThread);

/**
 * Messages
 */

// List messages in a thread (cursor pagination)
// GET /api/v1/messages/threads/:id/messages?before=<messageId>&after=<messageId>&limit=
router.get('/threads/:id/messages', requireAuth, messagesController.listMessages);

// Send a message to a thread
// POST /api/v1/messages/threads/:id/messages
// Body: { type:'text'|'image'|'video'|'audio'|'file'|'location', text?, attachments?, location?, replyTo? }
router.post('/threads/:id/messages', requireAuth, messagesController.sendMessage);

// Get a single message by id
// GET /api/v1/messages/:messageId
router.get('/:messageId', requireAuth, messagesController.getMessageById);

// Edit a message (text only; attachments immutable in this route)
// PATCH /api/v1/messages/:messageId
// Body: { text }
router.patch('/:messageId', requireAuth, messagesController.editMessage);

// Delete a message (soft delete)
// DELETE /api/v1/messages/:messageId
router.delete('/:messageId', requireAuth, messagesController.deleteMessage);

// Add a reaction to a message
// POST /api/v1/messages/:messageId/reactions
// Body: { emoji }
router.post('/:messageId/reactions', requireAuth, messagesController.addReaction);

// Remove a reaction from a message
// DELETE /api/v1/messages/:messageId/reactions
// Body: { emoji }
router.delete('/:messageId/reactions', requireAuth, messagesController.removeReaction);

// Thread location messages as RFC 7946 FeatureCollection for map overlay
// GET /api/v1/messages/threads/:id/geojson
router.get('/threads/:id/geojson', requireAuth, messagesController.getThreadGeoJSON);

module.exports = router;
