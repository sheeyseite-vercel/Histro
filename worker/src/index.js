// HISTO AI proxy (Cloudflare Worker).
// Keeps provider API keys off the phone and fails over between providers
// when one runs out of its daily quota or errors.
//
// Secrets (wrangler secret put NAME):
//   GROQ_API_KEY, GEMINI_API_KEY, OPENROUTER_API_KEY, MISTRAL_API_KEY, CEREBRAS_API_KEY  (use any you have)
//   APP_TOKEN  (optional; the app sends it in X-Histo-Key)
// Optional vars: PROVIDER_ORDER="groq,gemini,openrouter,mistral,cerebras"

const PROVIDERS = {
  groq: {
    url: 'https://api.groq.com/openai/v1/chat/completions',
    key: 'GROQ_API_KEY',
    model: 'llama-3.3-70b-versatile',
  },
  gemini: {
    url: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    key: 'GEMINI_API_KEY',
    model: 'gemini-2.0-flash',
  },
  openrouter: {
    url: 'https://openrouter.ai/api/v1/chat/completions',
    key: 'OPENROUTER_API_KEY',
    model: 'meta-llama/llama-3.3-70b-instruct:free',
  },
  mistral: {
    url: 'https://api.mistral.ai/v1/chat/completions',
    key: 'MISTRAL_API_KEY',
    model: 'mistral-small-latest',
  },
  cerebras: {
    url: 'https://api.cerebras.ai/v1/chat/completions',
    key: 'CEREBRAS_API_KEY',
    model: 'llama-3.3-70b',
  },
};

// Providers that returned a quota error are skipped until this time (ms).
const cooldown = new Map();

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, X-Histo-Key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS },
  });
}

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

async function callProvider(name, env, messages) {
  const p = PROVIDERS[name];
  const key = env[p.key];
  if (!key) return { skip: true };
  const model = env[`${name.toUpperCase()}_MODEL`] || p.model;
  let res;
  try {
    res = await fetch(p.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({ model, messages, temperature: 0.2, max_tokens: 900 }),
    });
  } catch (e) {
    return { error: 'network' };
  }
  if (res.status === 429 || res.status === 402 || res.status === 403) {
    // Quota or rate limit: park this provider until tomorrow (UTC).
    cooldown.set(name, res.status === 429 ? Date.now() + 5 * 60 * 1000 : nextUtcMidnight());
    return { error: `quota:${res.status}` };
  }
  if (!res.ok) return { error: `http:${res.status}` };
  const data = await res.json();
  const text = data?.choices?.[0]?.message?.content;
  if (!text) return { error: 'empty' };
  return { text: text.trim(), model };
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      const configured = Object.keys(PROVIDERS).filter((n) => env[PROVIDERS[n].key]);
      return json({ ok: true, providers: configured });
    }
    if (url.pathname !== '/chat' || request.method !== 'POST') {
      return json({ error: 'not_found' }, 404);
    }
    if (env.APP_TOKEN && request.headers.get('X-Histo-Key') !== env.APP_TOKEN) {
      return json({ error: 'unauthorized' }, 401);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'bad_json' }, 400);
    }
    const question = String(body.question || '').slice(0, 600);
    const lang = body.lang === 'ar' ? 'ar' : 'en';
    const context = Array.isArray(body.context) ? body.context.slice(0, 8) : [];
    if (!question || context.length === 0) return json({ error: 'missing_fields' }, 400);

    const messages = buildMessages(question, lang, context);
    const order = (env.PROVIDER_ORDER || 'groq,gemini,openrouter,mistral,cerebras')
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
      const r = await callProvider(name, env, messages);
      if (r.skip) continue;
      if (r.text) return json({ answer: r.text, provider: name, model: r.model });
      tried.push(`${name}:${r.error}`);
    }
    return json({ error: 'all_providers_failed', tried }, 503);
  },
};
