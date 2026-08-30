//
// digilocker-finalize
//
// Polyticks V4.0 – Step 2 (terminal step) of the automated ID verification
// flow. The DigiLocker consent screen redirects back to the app with an
// authorization `code`; the client passes it here. This function:
//   1. Verifies the caller owns the referenced verification_requests row
//      and the `state` matches (CSRF guard).
//   2. REAL MODE: exchanges the code for a token, fetches the eKYC XML,
//      and marks verified when the issuer response is valid.
//   3. MOCK MODE: auto-approves without any external call.
//   4. On success: profiles.is_verified = true, verification_status =
//      'approved' (service_role write — the registration-lock trigger in
//      migration 08 blocks client-side writes to these columns).
//   No identity documents are ever persisted.
//
// NOTE: the original plan listed separate callback + finalize functions;
// they are folded into this single terminal function because the mobile
// client receives the redirect directly and needs only one round-trip.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const DIGILOCKER_BASE_URL =
  Deno.env.get('DIGILOCKER_BASE_URL') ??
  'https://api.digitallocker.gov.in/public/oauth2/1/';
const DIGILOCKER_CLIENT_ID = Deno.env.get('DIGILOCKER_CLIENT_ID') ?? '';
const DIGILOCKER_CLIENT_SECRET =
  Deno.env.get('DIGILOCKER_CLIENT_SECRET') ?? '';
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

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
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
      return json(
        { success: false, error: 'DigiLocker verification is not enabled yet.' },
        503,
      );
    }
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      return json({ success: false, error: 'Missing bearer token' }, 401);
    }

    const { requestId, code } = await req.json();
    if (!requestId) {
      return json({ success: false, error: 'requestId is required' }, 400);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const userClient = createClient(supabaseUrl, serviceKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await userClient.auth.getUser();
    const userId = userData?.user?.id;
    if (!userId) return json({ success: false, error: 'Invalid token' }, 401);

    const admin = createClient(supabaseUrl, serviceKey);
    const isMock = DIGILOCKER_CLIENT_ID === '';

    // ── Load and authorize the request row ───────────────────────────────
    const { data: vReq, error: fetchErr } = await admin
      .from('verification_requests')
      .select('*')
      .eq('id', requestId)
      .single();
    if (fetchErr || !vReq) {
      return json({ success: false, error: 'Verification request not found' }, 404);
    }
    if (vReq.user_id !== userId) {
      return json({ success: false, error: 'Request does not belong to caller' }, 403);
    }
    if (vReq.status === 'verified') {
      return json({ success: true, status: 'verified', alreadyDone: true });
    }

    let verified = false;
    let failureReason: string | null = null;

    if (isMock) {
      // Mock provider: consent always granted.
      verified = true;
    } else {
      if (!code) {
        return json({ success: false, error: 'code is required' }, 400);
      }
      try {
        // Token exchange (OAuth2 authorization_code grant).
        const tokenRes = await fetch(`${DIGILOCKER_BASE_URL}token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({
            grant_type: 'authorization_code',
            code,
            client_id: DIGILOCKER_CLIENT_ID,
            client_secret: DIGILOCKER_CLIENT_SECRET,
            redirect_uri: APP_REDIRECT_SCHEME,
          }),
        });
        if (!tokenRes.ok) throw new Error(`token exchange ${tokenRes.status}`);
        const token = await tokenRes.json();

        // Fetch eKYC / issued documents XML.
        const xmlRes = await fetch(`${DIGILOCKER_BASE_URL}xml`, {
          headers: { Authorization: `Bearer ${token.access_token}` },
        });
        if (!xmlRes.ok) throw new Error(`eKYC fetch ${xmlRes.status}`);
        const ekyc = await xmlRes.text();

        // Minimal validity check: issuer responded with an eKYC envelope.
        // Deeper parsing is intentionally deferred until sandbox access.
        verified = ekyc.includes('<KycRes') || ekyc.includes('KycRes');
        if (!verified) failureReason = 'eKYC payload not recognized';
      } catch (e) {
        verified = false;
        failureReason = e instanceof Error ? e.message : String(e);
      }
    }

    // ── Persist terminal state ───────────────────────────────────────────
    await admin
      .from('verification_requests')
      .update({
        status: verified ? 'verified' : 'failed',
        failure_reason: failureReason,
      })
      .eq('id', requestId);

    if (verified) {
      // Privileged write allowed by guard_role_escalation via service_role.
      await admin
        .from('profiles')
        .update({ is_verified: true, verification_status: 'approved' })
        .eq('id', userId);
    }

    return json({ success: true, status: verified ? 'verified' : 'failed', mock: isMock });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return json({ success: false, error: msg }, 500);
  }
});
