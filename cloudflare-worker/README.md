# Polyticks Supabase Reverse Proxy

A Cloudflare Worker that sits between the Polyticks app (Flutter mobile + Web) and Supabase. Routes all Supabase API traffic through Cloudflare's edge to bypass ISP-level blocking of `*.supabase.co` domains in India.

## What it does

```
┌──────────────────┐      ┌───────────────────────┐      ┌──────────────────┐
│  Polyticks App   │ ───▶ │  Cloudflare Worker    │ ───▶ │  Supabase        │
│  (mobile / web)  │      │  (polyticks-api)      │      │  (sbdwwmboc...)  │
└──────────────────┘      └───────────────────────┘      └──────────────────┘
        │                          │                              │
        │                          │                              │
   ISP cannot see            Proxies all Supabase            Original backend
   "supabase.co"             API endpoints                  (auth, db, storage)
   in the URL or path
```

## Endpoints forwarded

| Path prefix     | Used for                                          |
| --------------- | ------------------------------------------------- |
| `/auth/v1/*`    | Login, signup, OTP, session refresh               |
| `/rest/v1/*`    | PostgREST table queries, RPCs, filters            |
| `/storage/v1/*` | File uploads, downloads, public/private buckets   |
| `/realtime/v1/*`| WebSocket channels (DB changes, presence, broadcast) |
| `/functions/v1/*`| Supabase Edge Functions (server-side code)        |

## Setup

### Prerequisites
- Node.js 18+
- A Cloudflare account (free tier works)
- A custom domain added to Cloudflare (e.g. `polyticks.in`)

### Local development
```bash
cd cloudflare-worker
npm install
npm run dev
```

This starts a local server on `http://localhost:8787` that mimics the Worker.

### Deploy to Cloudflare
```bash
cd cloudflare-worker
npx wrangler login              # one-time auth
npx wrangler deploy
```

After deploying, the Worker URL will be displayed. Note: on the **free plan**, `*.workers.dev` subdomains are restricted — you must attach a custom domain.

### Attach a custom domain
In the Cloudflare dashboard:
1. Go to **Workers & Pages** → `polyticks-api` → **Settings** → **Triggers** → **Custom Domains**
2. Add `api.polyticks.in` (or any subdomain of a Cloudflare-managed domain)

Or via `wrangler.toml`:
```toml
routes = [
  { pattern = "api.polyticks.in/*", zone_name = "polyticks.in" }
]
```

## Client configuration

### Flutter (mobile / desktop)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://api.polyticks.in \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

### Web (Vite / React)
In `.env.local`:
```env
NEXT_PUBLIC_SUPABASE_URL=https://api.polyticks.in
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<your-anon-key>
```

## Security notes

- The Worker **does not** add authentication — it just forwards traffic. The Supabase anon key in the client is still required and validated by Supabase's RLS.
- The `SUPABASE_HOST` is hardcoded in the Worker. The Supabase project URL itself is not exposed to clients.
- CORS is wide open for development. For production, lock down `ALLOWED_ORIGINS` in `src/index.js` to only your app's origins.
- All Supabase API keys are validated by Supabase's RLS, so an attacker can't bypass auth just by hitting the proxy.
