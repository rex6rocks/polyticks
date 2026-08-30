# Polyticks — Pending Tasks (consolidated)

> Single source of truth for all outstanding work, organized by the revised
> roadmap phases (`roadmap.md`). Completed work is recorded in
> `ProjectTracker.md` — nothing here has been started.
>
> Strategy: everything in V5 Phases A–C and V6 Phase D is done entirely in
> simulation/mock mode. Phase E (Alpha) requires real data and begins only
> after UI freeze.

## V5 Phase A — Design & Architecture Completion

- [ ] **A1. B17 Community Entities** — replace community name strings with a
      real `communities` table: schema + migration + RLS policies; backfill
      existing string references; rewire feed clustering, polls, community
      selector, and analytics rollups to rows instead of constants; remove the
      interim UUID-guard fallbacks once proven. Extend regression guards.
- [ ] **A2. Client-side key separation audit** — verify `service_role` key never
      compiles into client builds; Edge Function secrets only. (Last unchecked
      pre-prod audit item; see ProjectTracker.md.)
- [ ] **A3. AI screening proxy move** — route moderation calls through a Supabase
      Edge Function so `GROQ_API_KEY` never ships inside the app build.
      (Security review item 11.)

## V5 Phase B — Business Integration Layer Completion (all mocked)

- [ ] **B1. Subscription/billing flow hardening** — Razorpay stays mock/test
      mode: trial-expiry handling, upgrade/downgrade paths, webhook idempotency
      edge cases, entitlement enforcement across gated features.
- [ ] **B2. Priority Broadcast Configurator UI** — compose/schedule screen for
      targeted broadcast alerts (engine flag `priorityBroadcastEnabled` exists;
      no configurator UI built yet).
- [ ] **B3. eKYC response parsing deepened** — full DigiLocker identity-response
      parsing built and tested against sandbox-shaped fixtures (currently
      envelope-level only), making V6 go-live credentials-only.
- [ ] **B4. v4.1 Pro-ready seams finished as code** — everything except flipping
      live keys.

## V5 Phase C — Full Test Coverage Pass

- [ ] **C1. Test baseline cleanup** — triage/fix the 13 known environment-bound
      failures (`main_feed_screen_verification_test.dart`, env-dependent
      `models_test` / `rls_policies_test` / `supabase_triggers_test` /
      `widget_test`) before UI work starts.
- [ ] **C2. Trigger proof-runs in simulation harness** — dislike-surge (>60%)
      and report-surge (5-in-24h) legs exercised end-to-end on seeded offline
      data (production re-stamp happens in E1).
- [ ] **C3. Regression guards extended** — cover B17 entities and all new
      Phase A/B surfaces.

## V6 Phase D — UI Finalization

- [ ] **D1. Cross-platform design audit** — Flutter mobile + React web component
      parity; consistent empty/error/loading states.
- [ ] **D2. Business walkthrough & changes** — stakeholders review the full app
      in simulation mode; collect and implement recommended changes.
- [ ] **D3. UI freeze** — bug fixes only afterwards; gate for Alpha.

## Alpha Phase E — Real-Data Launch Activities (after UI freeze)

- [ ] **E1. Live trigger proof-runs** — dislike/report-surge legs re-run against
      production DB to formally close V2/V4 live verification.
- [ ] **E2. WhatsApp/X rich-link unfurl device checks** — V3 leftover; add a
      prerendered/SSR head layer for `/post/:id` if crawlers need it.
- [ ] **E3. Live AI smoke test** — flagged phrase → unsafe, clean civic phrase →
      safe through the screening proxy (blocked only on server-side GROQ key).
- [ ] **E4. Monetization go-live (v4.1 runbook)** — Supabase Pro upgrade,
      Razorpay live keys, `SUPABASE_TIER=pro`, priority broadcasts enabled,
      analytics retention raised (`docs/V4_SPEC.md` §4).
- [ ] **E5. DigiLocker live go-live execution** — sandbox approval → credentials
      secrets set → redeploy functions → real-device call-back test
      (roadmap.md V6 section).
- [ ] **E6. Load testing & scaled infrastructure** — prerequisite for v5.0
      enterprise features on real traffic.
- [ ] **E7. Store submissions & public launch** — Play Store public track;
      App Store submission with EULA/moderation terms.
