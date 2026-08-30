//
// digilocker-initiate
//
// Polyticks V4.0 – Step 1 of the automated ID verification flow.
// Creates a verification_requests row and returns the DigiLocker OAuth2
// consent URL for the client to open.
//
// MOCK MODE: when DIGILOCKER_CLIENT_ID is not configured (default during
// development / before govt sandbox approval), returns a synthetic consent
// URL so the full flow can be exercised end-to-end without credentials.
// See docs/V4_SPEC.md § 2 Phase 2.
//
// Auth: requires a valid user JWT (anon calls rejected).
// Writes: service_role only — clients have no write policies on
// verification_requests (migration 08).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const DIGILOCKER_BASE_URL =
  Deno.env.get('DIGILOCKER_BASE_URL') ??
  'https://api.digitallocker.gov.in/public/oauth2/1/';
const DIGILOCKER_CLIENT_ID = Deno.env.get('DIGILOCKER_CLIENT_ID') ?? '';
const APP_REDIRECT_SCHEME =
  Deno.env.get('DIGILOCKER_REDIRECT_URI') ?? 'polyticks://digilocker/callback';

// Kill-switch (V6 go-live guard): while absent/'false', the endpoint rejects
// ALL calls — including mock-mode auto-approvals — so a deployed-but-
// unconfigured function can never be used to self-verify. Set to 'true'
// only when going live (or deliberately testing on a private deployment).
const DIGILOCKER_ENABLED = Deno.env.get('DIGILOCKER_ENABLED') === 'true';

// CORS: browsers block cross-origin reads without these headers.
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, content-type, apikey, x-client-info, prefer',
};

function jsonError(message: string, status = 400) {
  return new Response(JSON.stringify({ success: false, error: message }), {
    headers: { 'Content-Type': 'application/json', ...CORS },
    status,
  });
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: CORS });
    }
    if (!DIGILOCKER_ENABLED) {
      return jsonError(
        'DigiLocker verification is not enabled yet.', 503);
    }
    // ── Auth gate ────────────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      return jsonError('Missing bearer token', 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const userClient = createClient(supabaseUrl, serviceKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await userClient.auth.getUser();
    const userId = userData?.user?.id;
    if (!userId) return jsonError('Invalid or expired token', 401);

    // Admin client (service_role) for privileged writes.
    const admin = createClient(supabaseUrl, serviceKey);

    const isMock = DIGILOCKER_CLIENT_ID === '';

    // ── Persist request row (state machine starts at 'initiated') ────────
    const requestId = crypto.randomUUID();
    const providerRequestId = isMock
      ? `mock-txn-${requestId.slice(0, 8)}`
      : null;

    const { error: insertErr } = await admin
      .from('verification_requests')
      .insert({
        id: requestId,
        user_id: userId,
        method: 'digilocker',
        status: 'initiated',
        provider_request_id: providerRequestId,
      });
    if (insertErr) {
      return jsonError(`DB insert failed: ${insertErr.message}`, 500);
    }

    // ── Build consent URL ────────────────────────────────────────────────
    let consentUrl: string;
    if (isMock) {
      consentUrl = `https://mock-digilocker.polyticks.local/consent?txn=${providerRequestId}`;
    } else {
      const params = new URLSearchParams({
        response_type: 'code',
        client_id: DIGILOCKER_CLIENT_ID,
        redirect_uri: APP_REDIRECT_SCHEME,
        state: requestId, // CSRF protection: echoed back & verified in finalize
      });
      consentUrl = `${DIGILOCKER_BASE_URL}authorize?${params.toString()}`;
    }

    return new Response(
      JSON.stringify({
        success: true,
        requestId,
        providerRequestId,
        mock: isMock,
        consentUrl,
      }),
      { headers: { 'Content-Type': 'application/json' }, status: 200 },
    );
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return jsonError(msg, 500);
  }
});
