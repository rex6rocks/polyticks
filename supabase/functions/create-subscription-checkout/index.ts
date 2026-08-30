//
// create-subscription-checkout
//
// Polyticks V4.0 – Phase 3, Step 1 of the paid-org flow.
// Creates a Razorpay subscription checkout session for the caller's org.
//
// MOCK MODE: when RAZORPAY_KEY_ID is not configured (default until the
// first paying org triggers the Pro/live update), a trialing subscription
// row is created directly and a synthetic checkout id is returned so the
// whole upgrade → badge flow can be exercised end-to-end.
//
// Body: { tier: 'gold' | 'platinum' }
// Auth: requires a valid user JWT.
// Writes: service_role only (subscriptions table has no client write policies).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID') ?? '';
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET') ?? '';

// Pricing per roadmap: $10–$50/mo → ₹829 (gold) / ₹4,149 (platinum) monthly.
const PLAN_IDS: Record<string, string> = {
  gold: Deno.env.get('RAZORPAY_PLAN_GOLD') ?? 'plan_gold_placeholder',
  platinum: Deno.env.get('RAZORPAY_PLAN_PLATINUM') ?? 'plan_platinum_placeholder',
};
const TRIAL_DAYS = 14; // roadmap risk mitigation: 14-day free trial

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
  // Preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }
  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      return json({ success: false, error: 'Missing bearer token' }, 401);
    }

    const { tier } = await req.json();
    if (tier !== 'gold' && tier !== 'platinum') {
      return json({ success: false, error: "tier must be 'gold' or 'platinum'" }, 400);
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
    const isMock = RAZORPAY_KEY_ID === '';

    // ── Guard: one live subscription per org ─────────────────────────────
    const { data: existing } = await admin
      .from('subscriptions')
      .select('*')
      .eq('org_id', userId)
      .single();

    if (
      existing &&
      ['trialing', 'active'].includes(existing.status) &&
      (existing.current_period_end === null ||
        new Date(existing.current_period_end) > new Date())
    ) {
      return json(
        { success: false, error: 'Org already has an active subscription' },
        409,
      );
    }

    // ── MOCK MODE: activate trial directly, skip provider ────────────────
    if (isMock) {
      const trialEnds = new Date(Date.now() + TRIAL_DAYS * 86400_000);
      const row = {
        org_id: userId,
        tier,
        status: 'trialing',
        provider: 'razorpay',
        provider_ref: `mock-sub-${crypto.randomUUID().slice(0, 8)}`,
        trial_ends_at: trialEnds.toISOString(),
        current_period_end: trialEnds.toISOString(),
      };
      const { error } = await admin
        .from('subscriptions')
        .upsert(row, { onConflict: 'org_id' });
      if (error) return json({ success: false, error: error.message }, 500);
      return json({
        success: true,
        mock: true,
        checkoutId: row.provider_ref,
        tier,
        trialEndsAt: row.trial_ends_at,
      });
    }

    // ── REAL MODE: Razorpay Subscriptions API ────────────────────────────
    const auth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
    const rpRes = await fetch('https://api.razorpay.com/v1/subscriptions', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        plan_id: PLAN_IDS[tier],
        total_count: 12, // 12 monthly cycles
        trial_period: TRIAL_DAYS,
        notes: { org_id: userId, tier },
      }),
    });
    if (!rpRes.ok) {
      const errBody = await rpRes.text();
      return json(
        { success: false, error: `Razorpay error ${rpRes.status}: ${errBody}` },
        502,
      );
    }
    const rpSub = await rpRes.json();

    // Persist as pending; the webhook flips it to trialing/active on payment.
    const { error } = await admin.from('subscriptions').upsert(
      {
        org_id: userId,
        tier,
        status: 'past_due',
        provider: 'razorpay',
        provider_ref: rpSub.id,
      },
      { onConflict: 'org_id' },
    );
    if (error) return json({ success: false, error: error.message }, 500);

    return json({
      success: true,
      mock: false,
      checkoutId: rpSub.id,
      tier,
      razorpayKeyId: RAZORPAY_KEY_ID, // public key id — safe for checkout SDK
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return json({ success: false, error: msg }, 500);
  }
});
