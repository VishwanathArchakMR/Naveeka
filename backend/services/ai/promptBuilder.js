// backend/services/ai/promptBuilder.js

/**
 * Builds a structured prompt payload for chat completion APIs.
 * Usage:
 *  const pb = buildPrompt({
 *    role: 'travel_guide',
 *    task: 'Suggest a 2-day temple-focused plan near Udupi.',
 *    context: { region: 'Udupi', preferences: ['Temples', 'Spiritual'] },
 *    requireJSON: true,
 *    jsonSchemaHint: { type: 'object', properties: { days: { type: 'number' } } }
 *  });
 *  // pb.messages => [{role:'system',content:'...'}, {role:'user',content:'...'}]
 */
function buildPrompt({ role = 'assistant', task, context = null, requireJSON = false, jsonSchemaHint = null }) {
        const systemParts = [];
      
        // Role and scope
        if (role === 'travel_guide') {
          systemParts.push(
            'You are an expert Indian travel guide for spiritual and nature trips. Keep responses concise, actionable, and region-aware.'
          );
        } else if (role === 'planner') {
          systemParts.push(
            'You are a trip planning assistant. Provide step-by-step itineraries, distance-aware sequencing, and budget-sensitive tips.'
          );
        } else if (role === 'social_captions') {
          systemParts.push(
            'You craft short, engaging social captions with 3-5 relevant hashtags. Avoid overuse of emojis.'
          );
        } else {
          systemParts.push('You are a helpful assistant for travel discovery, social content, and bookings.');
        } // role prompting patterns [4]
      
        // Output constraints
        if (requireJSON) {
          systemParts.push('Always respond with valid JSON only. No extra text, no Markdown.'); // JSON output prefix guidance [4]
          if (jsonSchemaHint) {
            systemParts.push(`Schema hint: ${JSON.stringify(jsonSchemaHint)}`);
          }
        }
      
        const system = systemParts.join(' ');
      
        const user = [
          task ? `Task: ${task}` : null,
          context ? `Context: ${JSON.stringify(context)}` : null
        ]
          .filter(Boolean)
          .join('\n');
      
        return {
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: user || 'Provide helpful guidance.' }
          ],
          // Optional knobs that a caller can pass through to the AI client
          options: {
            temperature: role === 'social_captions' ? 0.7 : 0.3,
            maxTokens: 400
          }
        };
      }
      
      module.exports = { buildPrompt };
      