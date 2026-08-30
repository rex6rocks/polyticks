/**
 * Polyticks Supabase Reverse Proxy
 * ──────────────────────────────────
 * Bypasses ISP-level blocking of *.supabase.co in India by routing
 * traffic through Cloudflare's edge network. The Flutter/Web app talks
 * to this Worker URL; the Worker forwards to Supabase transparently.
 *
 * Endpoints forwarded (all sub-paths included):
 *   - /auth/v1/*       (GoTrue authentication: login, signup, OTP, etc.)
 *   - /rest/v1/*       (PostgREST: tables, RPCs, etc.)
 *   - /storage/v1/*    (Object storage: buckets, uploads)
 *   - /realtime/v1/*   (WebSocket realtime channels)
 *   - /functions/v1/*  (Supabase Edge Functions)
 *   - /pg/*            (Postgres direct connections - rarely used)
 *
 * Header forwarding:
 *   - Host is rewritten to the Supabase origin
 *   - Cloudflare-specific headers are stripped
 *   - CORS headers are added to every response (including errors)
 *   - WebSocket upgrade requests (realtime) are passed through
 */

const SUPABASE_HOST = "sbdwwmbocyqlkztptskb.supabase.co";

// Origins allowed to make CORS requests. In production, lock this down
// to your actual app origins (Flutter Web, capacitor://, app://, etc.)
const ALLOWED_ORIGINS = [
  "https://polyticks.in",
  "https://www.polyticks.in",
  "https://app.polyticks.in",
  "https://web.polyticks.in",
  "http://localhost:3000",
  "http://localhost:5173",
  "http://localhost:8080",
  "capacitor://localhost",
  "app://polyticks",
  "ionic://localhost",
];

const SUPABASE_PATH_PREFIXES = [
  "/auth/",
  "/rest/",
  "/storage/",
  "/realtime/",
  "/functions/",
  "/pg/",
];

function isSupabasePath(pathname) {
  if (pathname === "/" || pathname === "") return true; // health check
  return SUPABASE_PATH_PREFIXES.some((p) => pathname.startsWith(p));
}

function corsHeaders(request) {
  const origin = request.headers.get("Origin") || request.headers.get("origin") || "*";
  const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : "*";
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    "Access-Control-Allow-Headers":
      "Authorization, apikey, x-client-info, content-type, x-supabase-api-version, range, prefer",
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Max-Age": "86400",
  };
}

function jsonResponse(body, status, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      ...extraHeaders,
    },
  });
}

async function handleRequest(request) {
  // 1. CORS preflight
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(request) });
  }

  const url = new URL(request.url);

  // 2. Path whitelist (only forward Supabase API paths)
  if (!isSupabasePath(url.pathname)) {
    return jsonResponse(
      {
        error: "Not Found",
        message:
          "This proxy only forwards Supabase API requests. " +
          "Use /auth/, /rest/, /storage/, /realtime/, or /functions/.",
      },
      404,
      corsHeaders(request)
    );
  }

  // 3. Rewrite URL to point at Supabase
  url.hostname = SUPABASE_HOST;
  url.protocol = "https:";

  // 4. Build clean headers
  const newHeaders = new Headers(request.headers);
  newHeaders.set("Host", SUPABASE_HOST);
  // Strip Cloudflare-specific headers that should not reach Supabase
  newHeaders.delete("cf-connecting-ip");
  newHeaders.delete("cf-ray");
  newHeaders.delete("cf-request-id");
  newHeaders.delete("cf-worker");
  newHeaders.delete("cf-visitor");

  // 5. WebSocket upgrade (Supabase Realtime)
  if (request.headers.get("Upgrade")?.toLowerCase() === "websocket") {
    return fetch(url.toString(), {
      headers: newHeaders,
      body: request.body,
      cf: { webSocket: true },
    });
  }

  // 6. Forward regular HTTP request
  let response;
  try {
    response = await fetch(
      new Request(url.toString(), {
        method: request.method,
        headers: newHeaders,
        body: request.body,
        redirect: "follow",
      })
    );
  } catch (err) {
    return jsonResponse(
      { error: "Proxy Error", message: err.message },
      502,
      corsHeaders(request)
    );
  }

  // 7. Add CORS headers to upstream response
  const responseHeaders = new Headers(response.headers);
  for (const [k, v] of Object.entries(corsHeaders(request))) {
    responseHeaders.set(k, v);
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: responseHeaders,
  });
}

addEventListener("fetch", (event) => {
  event.respondWith(handleRequest(event.request));
});
