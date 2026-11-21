# HISTO

A bilingual (English main, Arabic) history atlas. Instead of shipping hand-written
articles, HISTO reads topics **live from open references** and shows them with their
footnotes, infobox facts, dates and map positions.

## How content is fetched

| Need | Source |
| --- | --- |
| Search | Wikipedia search API (app language, falls back to English) |
| Article text, sections, footnotes, infobox | Wikipedia REST API (`/page/html`), parsed in `lib/core/parser.dart` |
| Intro, image, coordinates | Wikipedia REST `/page/summary` |
| Year of an event or person | Wikidata (`P585`, `P580`, `P571`, `P569`) |
| Arabic/English pair | Wikipedia language links |
| Today in history | Wikimedia `onthisday` feed |
| Map | OpenStreetMap tiles (sepia filter), pins from articles you open |

Every article page shows the footnotes of the original and a link to it. Text is under
CC BY-SA 4.0 (Wikipedia); the app shows this notice on each article.

## AI assistant

The assistant never answers from memory. For each question the app picks the most
relevant passages of the open article (or of the top search results), sends them to the
proxy in `worker/`, and the model must answer only from those passages and cite them.
If the proxy is unreachable, the app shows the matching passages themselves.

The proxy (`worker/`) tries providers in order (Groq, Gemini, OpenRouter, Mistral,
Cerebras). On a quota error (429/402/403) a provider is skipped until the next UTC day
and the next one is used. API keys stay in Cloudflare secrets, not in the APK.

### Deploy the proxy

```bash
cd worker
npm i -g wrangler
wrangler login
wrangler secret put GROQ_API_KEY        # add any of the providers you have
wrangler secret put GEMINI_API_KEY
wrangler secret put OPENROUTER_API_KEY
wrangler secret put APP_TOKEN           # any random string
wrangler deploy
```

Then in the GitHub repo: **Settings > Secrets and variables > Actions**
- Variable `HISTO_PROXY_URL` = the worker URL (for example `https://histo-ai-proxy.you.workers.dev`)
- Secret `HISTO_APP_TOKEN` = the same value as `APP_TOKEN`

## Build the APK

Push to `main` (or run the "Build APK" workflow). The APK appears as a workflow artifact
and under **Releases > latest**. The workflow generates the Android project with
`flutter create`, so no Android files are stored in the repo.

## Run locally

```bash
flutter pub get
flutter run --dart-define=HISTO_PROXY_URL=https://your-worker.workers.dev
```

## Known limits

- Wikipedia is a good starting point, not an infallible one. Always check the footnotes.
- Articles are shown in the language they were written in. There is no machine translation.
- Fonts load from Google Fonts at first use, so the very first launch needs internet.

## Live proxy (Vercel)

The proxy is also available as a Vercel function in `api/chat.js` (project `histo-ai`).
Provider keys are Vercel environment variables (`GROQ_API_KEY`, `OPENAI_API_KEY`,
`APP_TOKEN`). The workflow defaults `HISTO_PROXY_URL` to `https://histo-ai.vercel.app/api`;
add the repository secret `HISTO_APP_TOKEN` (same value as `APP_TOKEN`) so the app can call it.
