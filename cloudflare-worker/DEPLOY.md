# Deploying the Cloudflare Worker

## Prerequisites
- Node.js 18+
- A Cloudflare account (free tier OK)
- A custom domain is **not** required for development — the free
  `*.workers.dev` URL works fine. You only need a custom domain
  for production (see "Production domain" section at the bottom).

## One-time setup

### Option A: Interactive (easiest)
```bash
cd cloudflare-worker
npx wrangler login
```
This opens a browser tab for OAuth. After login, you're authenticated.

### Option B: API token (CI / non-interactive)
1. Cloudflare Dashboard → My Profile → API Tokens → Create Token
2. Use the "Edit Cloudflare Workers" template
3. Set the token as an env var:
   ```bash
   $env:CLOUDFLARE_API_TOKEN = "your-token-here"
   ```

## Deploy the Worker

```bash
cd cloudflare-worker
npm install
npx wrangler deploy
```

This will:
1. Upload `src/index.js` to the `polyticks-api` Worker
2. Overwrite the existing script with the improved version (CORS, path whitelist, WebSocket support)
3. Print the Worker URL (will be `polyticks-api.rex6rocks.workers.dev`)

## Verify the deployment

```bash
# Health check
curl https://polyticks-api.rex6rocks.workers.dev/

# Auth health
curl -H "apikey: test" https://polyticks-api.rex6rocks.workers.dev/auth/v1/health
```

## ⚠️ Note about the free plan

On the free plan, `*.workers.dev` URLs may return `403 Forbidden: requests to <name>.workers.dev are not allowed`. This is because the free plan restricts the public `workers.dev` routing to paid plans.

**Solution 1 (recommended):** Attach a custom domain.
```bash
# In wrangler.toml, uncomment the routes block:
# routes = [
#   { pattern = "api.polyticks.in/*", zone_name = "polyticks.in" }
# ]
```
Then update `polyticks.in` nameservers to Cloudflare's:
- `audrey.ns.cloudflare.com`
- `thomas.ns.cloudflare.com`

After DNS propagates, the Worker will be reachable at `https://api.polyticks.in`.

**Solution 2:** Upgrade to the Workers paid plan ($5/mo) for unlimited `workers.dev` access.

**Solution 3 (temporary):** Test with `npx wrangler dev` locally — runs on `http://localhost:8787`.

## Update Flutter to use the proxy

Once deployed, run:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://polyticks-api.rex6rocks.workers.dev \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_arEuCFtXNCtnJxZFrt8PBQ__-fSxKuE
```

(Or if you attached a custom domain, use `https://api.polyticks.in`.)

## Update Web

The web `.env.local` is already configured. Just rebuild:
```bash
npm run build
```

## Production domain (custom-domain upgrade)

For production you'll want a clean branded URL like `https://api.polyticks.in`
instead of `polyticks-api.rex6rocks.workers.dev`. This is a free upgrade
on the Workers free plan — you only pay for the domain itself.

**Full runbook is in `pending/PENDING_TASKS.md` → item E8.**

TL;DR:
1. Buy `polyticks.in` (or similar) — ~$10-15/yr
2. Add the zone to Cloudflare, point registrar nameservers to Cloudflare's
3. Dashboard → Workers & Pages → `polyticks-api` → Settings → Triggers → Custom Domains → add `api.polyticks.in`
4. Update env vars (`local_keys.json`, `.env.local`, Flutter `--dart-define`)
5. Add the new domain to `ALLOWED_ORIGINS` in `src/index.js` and re-deploy the Worker

No Workers plan upgrade required for normal traffic.
