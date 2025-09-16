// backend/controllers/ai/chatController.js

/**
 * POST /api/traveos.ai/chat
 * Body: { message: string, context?: object }
 * Returns: { text: string, suggestions: [{ title, action }] }
 *
 * This is a stub for Phase 1 MVP. Replace with a real AI service later.
 */
exports.chat = async (req, res) => {
        try {
          const { message, context } = req.body || {};
      
          if (!message || String(message).trim().length === 0) {
            return res.status(400).json({ success: false, message: 'message is required' });
          }
      
          const reply = {
            text: `Planning helper: Received "${String(message).trim()}". Context: ${JSON.stringify(context || {})}.`,
            suggestions: [
              { title: 'Find temples near Udupi', action: { type: 'search', query: 'Temples Udupi' } },
              { title: '3-day coastal plan', action: { type: 'plan', days: 3, region: 'Udupi' } }
            ]
          };
      
          return res.json({ success: true, data: reply }); // proper JSON response in Express [1][5]
        } catch (err) {
          console.error('AI chat error:', err);
          return res.status(500).json({ success: false, message: 'Server error' });
        }
      };
      