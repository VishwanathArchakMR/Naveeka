// backend/services/aiService.js
// Provider-agnostic AI helper that converts a free-form query into structured filters.
// It NEVER fabricates places; controllers use the filters to query your Place collection.

const fetch = (...args) => import('node-fetch').then(({ default: f }) => f(...args)).catch(() => null);

// App-specific enums
const EMOTIONS = ['Spiritual', 'Peaceful', 'Adventure', 'Nature', 'Heritage'];
const CATEGORIES = ['Temples', 'Peaceful', 'Adventure', 'Heritage', 'Nature', 'Stay Places'];

const PROVIDER = (process.env.AI_PROVIDER || 'mock').toLowerCase(); // 'openai' | 'huggingface' | 'mock'

/**
 * Basic keyword heuristics for the mock provider.
 * Maps common words/phrases to emotions/categories/keywords safely.
 */
function heuristicFilters(queryText) {
  const q = (queryText || '').toLowerCase();

  const emotions = new Set();
  const categories = new Set();
  const keywords = new Set();

  // Emotions
  if (/(peace|calm|relax|serene|silence)/.test(q)) emotions.add('Peaceful');
  if (/(spirit|temple|divine|pilgrim|ashram)/.test(q)) emotions.add('Spiritual');
  if (/(adventure|trek|hike|climb|camp|rafting)/.test(q)) emotions.add('Adventure');
  if (/(forest|nature|waterfall|lake|beach|mountain|wildlife|park)/.test(q)) emotions.add('Nature');
  if (/(heritage|history|fort|palace|monument|ruins|museum)/.test(q)) emotions.add('Heritage');

  // Categories
  if (/(temple|ashram|pooja|darshan)/.test(q)) categories.add('Temples');
  if (/(resort|hotel|stay|homestay)/.test(q)) categories.add('Stay Places');
  if (/(trek|hike|adventure|climb|camp)/.test(q)) categories.add('Adventure');
  if (/(heritage|fort|palace|monument|ruins|museum)/.test(q)) categories.add('Heritage');
  if (/(park|forest|beach|lake|mountain|waterfall)/.test(q)) categories.add('Nature');
  if (/(peace|calm|quiet|meditation|retreat)/.test(q)) categories.add('Peaceful');

  // Region extraction (very naive heuristic; controller applies regex on regionPath)
  let region = null;
  const regionMatch = q.match(/\b(in|near|around)\s+([a-zA-Z\s]{2,})/);
  if (regionMatch && regionMatch[2]) {
    region = regionMatch.trim();
  }

  // Price hints
  let priceMin = 0;
  let priceMax;
  if (/\b(budget|cheap|low cost|affordable)\b/.test(q)) priceMax = 1000;
  if (/\b(premium|luxury|high end|expensive)\b/.test(q)) priceMin = 3000;

  // Collect potential keywords (simple split; controller uses regex OR across fields)
  (q.replace(/[^\p{L}\p{N}\s]/gu, '').split(/\s+/).filter(Boolean) || []).forEach(k => {
    if (k.length >= 3) keywords.add(k);
  });

  return {
    emotions: Array.from(emotions),
    categories: Array.from(categories),
    keywords: Array.from(keywords).slice(0, 15),
    region,
    priceMin,
    priceMax
  };
}

/**
 * OpenAI provider call (optional).
 * Requires: OPENAI_API_KEY
 * Note: This extracts filters only; the DB query is done in the controller.
 */
async function openaiFilters(user, queryText, options) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey || !fetch) {
    // Fallback to heuristic if not available
    return heuristicFilters(queryText);
  }

  const system = `You classify travel intent into the following enums:
Emotions: ${EMOTIONS.join(', ')}
Categories: ${CATEGORIES.join(', ')}
Return strict JSON with keys: emotions[], categories[], keywords[], region (string|null), priceMin (number), priceMax (number|null). Do not include any text outside JSON.`;

  const userPrompt = `User query: "${queryText}"
Rules:
- Map to 0-2 emotions max.
- Map to 0-3 categories max.
- Provide up to 10 keywords (lowercase).
- region: infer as a simple place/area string if present; otherwise null.
- priceMin/priceMax: infer rough budget from phrases (budget/affordable vs premium/luxury); else 0 and null.`;

  // Use OpenAI Chat Completions v1. This is a minimal example; adjust as needed.
  const body = {
    model: process.env.OPENAI_MODEL || 'gpt-4o-mini',
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: userPrompt }
    ],
    temperature: 0.2,
    max_tokens: 300
  };

  const t0 = Date.now();
  try {
    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });

    const json = await resp.json();
    const content = json?.choices?.[0]?.message?.content || '{}';
    const parsed = JSON.parse(content);

    // Sanitize with enums
    const emotions = (parsed.emotions || []).filter(e => EMOTIONS.includes(e));
    const categories = (parsed.categories || []).filter(c => CATEGORIES.includes(c));
    const keywords = Array.isArray(parsed.keywords)
      ? parsed.keywords.map(k => String(k || '').toLowerCase()).slice(0, 15)
      : [];

    const region = typeof parsed.region === 'string' && parsed.region.trim() ? parsed.region.trim() : null;
    const priceMin = Number.isFinite(parsed.priceMin) ? Math.max(0, parsed.priceMin) : 0;
    const priceMax = Number.isFinite(parsed.priceMax) ? Math.max(0, parsed.priceMax) : undefined;

    return { emotions, categories, keywords, region, priceMin, priceMax, _latency: Date.now() - t0, _provider: 'openai' };
  } catch (e) {
    // Fallback to heuristic on any failure
    const h = heuristicFilters(queryText);
    h._latency = Date.now() - t0;
    h._provider = 'openai-fallback';
    return h;
  }
}

/**
 * Hugging Face provider call (optional).
 * Requires: HUGGINGFACE_API_KEY and a text classification/generation model.
 * Similar approach to OpenAI; return structured filters.
 */
async function huggingfaceFilters(user, queryText, options) {
  const apiKey = process.env.HUGGINGFACE_API_KEY;
  if (!apiKey || !fetch) {
    return heuristicFilters(queryText);
  }

  // This is a placeholder. In practice, you would:
  // 1) Hit a HF endpoint with your prompt.
  // 2) Parse the JSON response.
  // For now, return heuristic to keep things stable.
  return heuristicFilters(queryText);
}

/**
 * Public API: generate journey suggestions content (filters only).
 * Controller uses these filters to query Place. We return metadata for rationale and provider.
 */
async function generateJourneySuggestions(user, queryText, options = {}) {
  const t0 = Date.now();

  let filters;
  let provider = PROVIDER;

  if (PROVIDER === 'openai') {
    const r = await openaiFilters(user, queryText, options);
    filters = r;
    provider = r._provider || 'openai';
  } else if (PROVIDER === 'huggingface') {
    const r = await huggingfaceFilters(user, queryText, options);
    filters = r;
    provider = r._provider || 'huggingface';
  } else {
    // mock / default
    filters = heuristicFilters(queryText);
    provider = 'mock';
  }

  const rationale = buildRationale(queryText, filters);
  const latencyMs = (filters && filters._latency) || (Date.now() - t0);

  // Remove private helper keys
  const { _latency, _provider, ...cleanFilters } = filters || {};

  // The service does NOT fabricate places; it only returns filters and rationale.
  return {
    filters: cleanFilters,
    suggestions: [], // Controller will query DB and construct final suggestions
    rationale,
    provider,
    latencyMs
  };
}

/**
 * Create a simple, human-friendly rationale based on derived filters.
 */
function buildRationale(queryText, filters) {
  const chunks = [];
  if (filters?.emotions?.length) {
    chunks.push(`tuned for ${filters.emotions.join(' and ')}`);
  }
  if (filters?.categories?.length) {
    chunks.push(`focused on ${filters.categories.join(', ')}`);
  }
  if (filters?.region) {
    chunks.push(`around ${filters.region}`);
  }
  if (typeof filters?.priceMin === 'number' || typeof filters?.priceMax === 'number') {
    const parts = [];
    if (typeof filters.priceMin === 'number' && filters.priceMin > 0) parts.push(`₹${filters.priceMin}+`);
    if (typeof filters.priceMax === 'number') parts.push(`up to ₹${filters.priceMax}`);
    if (parts.length) chunks.push(`within ${parts.join(' ')}`);
  }

  const basis = chunks.length ? chunks.join(', ') : 'based on your intent';
  return `Suggestions ${basis}.`;
}

module.exports = {
  generateJourneySuggestions
};
