//
// payment-webhook
//
// Polyticks V4.0 – Phase 3, Step 2 of the paid-org flow.
// Receives Razorpay subscription webhooks and activates/renews/cancels
// org subscriptions.
//
// IDEMPOTENCY CONTRACT (free-tier pause survival):
//   1. Every delivery is INSERTed into webhook_events first; the
//      (provider, event_id) unique key absorbs duplicates.
//   2. If the insert conflicts, the event was already processed → 200 OK.
//   3. Razorpay retries failed deliveries automatically, so a missed
//      delivery during a project pause self-heals after upgrade.
//
// Signature: X-Razorpay-Signature = HMAC-SHA256(rawBody, RAZORPAY_WEBHOOK_SECRET).
// Auth: none (provider call) — signature IS the auth.
// Writes: service_role only.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RAZORPAY_WEBHOOK_SECRET =
  Deno.env.get('RAZORPAY_WEBHOOK_SECRET') ?? '';

async function hmacSha256Hex(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(payload),
  );
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { 'Content-Type': 'application/json' },
    status,
  });
}

Deno.serve(async (req: Request) => {
  try {
    const rawBody = await req.text();
    const signature = req.headers.get('X-Razorpay-Signature') ?? '';

    // ── Signature verification (skip only in mock/dev mode) ──────────────
    if (RAZORPAY_WEBHOOK_SECRET !== '') {
      const expected = await hmacSha256Hex(RAZORPAY_WEBHOOK_SECRET, rawBody);
      if (expected !== signature) {
        return json({ success: false, error: 'Invalid signature' }, 401);
      }
    }

    const event = JSON.parse(rawBody);
    const eventId: string =
      event?.payload?.subscription?.entity?.id ??
      event?.id ??
      crypto.randomUUID();
    const eventType: string = event?.event ?? 'unknown';
    const sub = event?.payload?.subscription?.entity ?? {};
    const orgId: string | undefined = sub?.notes?.org_id;

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const admin = createClient(supabaseUrl, serviceKey);

    // ── Idempotency gate ─────────────────────────────────────────────────
    const { error: dedupeErr } = await admin.from('webhook_events').insert({
      provider: 'razorpay',
      event_id: eventId,
      event_type: eventType,
      payload: event,
    });

    if (dedupeErr) {
      // Unique violation → replay of an already-processed event.
      return json({ success: true, deduped: true, eventId });
    }

    // ── State machine: map Razorpay events → subscription_status ─────────
    let newStatus: string | null = null;
    switch (eventType) {
      case 'subscription.activated':
        newStatus = 'active';
        break;
      case 'subscription.charged': // renewal
        newStatus = 'active';
        break;
      case 'subscription.pending':
        newStatus = 'past_due';
        break;
      case 'subscription.halted':
      case 'subscription.cancelled':
        newStatus = 'canceled';
        break;
      case 'subscription.completed': // finished all cycles
        newStatus = 'expired';
        break;
      default:
        break; // unknown event types are logged but not acted on
    }

    let processedError: string | null = null;
    if (newStatus !== null && orgId) {
      const periodEnd = sub?.current_end
        ? new Date(sub.current_end * 1000).toISOString()
        : null;
      const { error } = await admin
        .from('subscriptions')
        .update({
          status: newStatus,
          tier:
            sub?.notes?.tier === 'platinum'
              ? 'platinum'
              : sub?.notes?.tier === 'gold'
                ? 'gold'
                : 'basic',
          current_period_end: periodEnd,
          canceled_at:
            newStatus === 'canceled' ? new Date().toISOString() : null,
        })
        .eq('org_id', orgId);
      if (error) processedError = error.message;
    } else if (newStatus !== null && !orgId) {
      processedError = 'Missing notes.org_id on subscription entity';
    }

    // Mark the event as processed (or record the failure for observability).
    await admin
      .from('webhook_events')
      .update({ processed_at: new Date().toISOString(), process_error: processedError })
      .eq('provider', 'razorpay')
      .eq('event_id', eventId);

    return json({
      success: processedError === null,
      eventId,
      eventType,
      appliedStatus: newStatus,
      error: processedError ?? undefined,
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return json({ success: false, error: msg }, 500);
  }
});
