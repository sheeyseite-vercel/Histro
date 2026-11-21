// HISTO AI proxy (Vercel serverless function).
// Keys live in Vercel environment variables, never in the app.
// Env: GROQ_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY, OPENROUTER_API_KEY, MISTRAL_API_KEY (any you have)
//      APP_TOKEN (shared token the app sends in X-Histo-Key)
//      PROVIDER_ORDER (optional) e.g. "groq,openai,gemini"

const PROVIDERS = {
  groq: { url: 'https://api.groq.com/openai/v1/chat/completions', key: 'GROQ_API_KEY', model: 'llama-3.3-70b-versatile' },
  openai: { url: 'https://api.openai.com/v1/chat/completions', key: 'OPENAI_API_KEY', model: 'gpt-4o-mini' },
  gemini: { url: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions', key: 'GEMINI_API_KEY', model: 'gemini-2.0-flash' },
  openrouter: { url: 'https://openrouter.ai/api/v1/chat/completions', key: 'OPENROUTER_API_KEY', model: 'meta-llama/llama-3.3-70b-instruct:free' },
  mistral: { url: 'https://api.mistral.ai/v1/chat/completions', key: 'MISTRAL_API_KEY', model: 'mistral-small-latest' },
};

// A provider that hit its quota is skipped until this time (ms). Best effort per warm instance.
const cooldown = new Map();

function nextUtcMidnight() {
  const d = new Date();
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1);
}

function buildMessages(question, lang, context) {
  const ctx = context
    .map((c) => `[${c.n}] ${c.title}${c.section ? ' - ' + c.section : ''}\n${c.text}`)
    .join('\n\n');
  const language = lang === 'ar' ? 'Arabic (Modern Standard Arabic)' : 'English';
  const system = [
    'You are the assistant of HISTO, a history reference app.',
    'Answer ONLY from the numbered source passages provided. Do not use outside knowledge.',
    'If the passages do not contain the answer, say so plainly and do not guess.',
    'Give exact dates, names and figures as they appear in the passages.',
    'If the passages disagree or hedge (for example "according to" or "some scholars"), say so.',
    'Cite passages inline like [1] or [2].',
    `Write the answer in ${language}. Keep it clear and well organised.`,
  ].join(' ');
  return [
    { role: 'system', content: system },
    { role: 'user', content: `Source passages:\n\n${ctx}\n\nQuestion: ${question}` },
  ];
}

async function callProvider(name, messages) {
  const p = PROVIDERS[name];
  const key = process.env[p.key];
  if (!key) return { skip: true };
  const model = process.env[`${name.toUpperCase()}_MODEL`] || p.model;
  let res;
  try {
    res = await fetch(p.url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
      body: JSON.stringify({ model, messages, temperature: 0.2, max_tokens: 900 }),
    });
  } catch (e) {
    return { error: 'network' };
  }
  // Quota / rate limit / billing / auth problems: park the provider and move on.
  if ([401, 402, 403, 429].includes(res.status)) {
    cooldown.set(name, res.status === 429 ? Date.now() + 5 * 60 * 1000 : nextUtcMidnight());
    return { error: `quota_or_auth:${res.status}` };
  }
  if (!res.ok) return { error: `http:${res.status}` };
  const data = await res.json();
  const text = data && data.choices && data.choices[0] && data.choices[0].message && data.choices[0].message.content;
  if (!text) return { error: 'empty' };
  return { text: text.trim(), model };
}

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Histo-Key');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();

  if (req.method === 'GET') {
    const configured = Object.keys(PROVIDERS).filter((n) => process.env[PROVIDERS[n].key]);
    return res.status(200).json({ ok: true, providers: configured });
  }
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

  if (process.env.APP_TOKEN && req.headers['x-histo-key'] !== process.env.APP_TOKEN) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
  const question = String(body.question || '').slice(0, 600);
  const lang = body.lang === 'ar' ? 'ar' : 'en';
  const context = Array.isArray(body.context) ? body.context.slice(0, 8) : [];
  if (!question || context.length === 0) return res.status(400).json({ error: 'missing_fields' });

  const messages = buildMessages(question, lang, context);
  const order = (process.env.PROVIDER_ORDER || 'groq,openai,gemini,openrouter,mistral')
    .split(',')
    .map((s) => s.trim())
    .filter((s) => PROVIDERS[s]);

  const tried = [];
  for (const name of order) {
    const until = cooldown.get(name);
    if (until && until > Date.now()) {
      tried.push(`${name}:cooldown`);
      continue;
    }
    const r = await callProvider(name, messages);
    if (r.skip) continue;
    if (r.text) return res.status(200).json({ answer: r.text, provider: name, model: r.model });
    tried.push(`${name}:${r.error}`);
  }
  return res.status(503).json({ error: 'all_providers_failed', tried });
};
