//
// cancel-subscription
//
// Polyticks V4.0 – Phase 3, Step 3 of the paid-org flow.
// Cancels the caller's org subscription.
//
// MOCK MODE: marks the row 'canceled' directly (no provider call).
// REAL MODE: cancels at Razorpay (effective at cycle end) and mirrors
// status locally; the webhook remains the source of truth for final state.
//
// Auth: requires a valid user JWT; only the owning org may cancel.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID') ?? '';
const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET') ?? '';

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
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }
  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader.startsWith('Bearer ')) {
      return json({ success: false, error: 'Missing bearer token' }, 401);
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

    const { data: sub, error } = await admin
      .from('subscriptions')
      .select('*')
      .eq('org_id', userId)
      .single();
    if (error || !sub) {
      return json({ success: false, error: 'No subscription found' }, 404);
    }
    if (!['trialing', 'active', 'past_due'].includes(sub.status)) {
      return json(
        { success: false, error: `Subscription already ${sub.status}` },
        409,
      );
    }

    // Real mode: request cancellation at the provider first.
    let providerError: string | null = null;
    if (!isMock && sub.provider_ref && !sub.provider_ref.startsWith('mock-')) {
      const auth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`);
      const rpRes = await fetch(
        `https://api.razorpay.com/v1/subscriptions/${sub.provider_ref}/cancel`,
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${auth}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ cancel_at_cycle_end: true }),
        },
      );
      if (!rpRes.ok) {
        providerError = `Razorpay cancel failed (${rpRes.status})`;
      }
    }

    if (providerError === null) {
      await admin
        .from('subscriptions')
        .update({ status: 'canceled', canceled_at: new Date().toISOString() })
        .eq('org_id', userId);
    }

    return json({ success: providerError === null, mock: isMock, error: providerError ?? undefined });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return json({ success: false, error: msg }, 500);
  }
});
