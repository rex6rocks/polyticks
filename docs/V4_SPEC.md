# Polyticks V4.0 — Spec: Automated Scale & Monetization (Free-Tier First)

> Created 2026-08-23. Governs the v4.0 implementation.
> Companion docs: `roadmap.md` (§ VERSION 4.0), `blueprint.md`, `docs/V2_STATE_MANAGEMENT_SPEC.md`.

## 0. Launch strategy — FREE tier now, PRO later

v4.0 ships **entirely on Supabase Free tier**. The Pro upgrade is deferred to
a post-release update (v4.1) triggered when the first org is ready to pay.
Everything that Pro affects has been given a thin abstraction or placeholder
("pro-ready seam") so the upgrade is config-only.

| Future Pro need | Placeholder shipped in v4.0 | Upgrade action |
| --- | --- | --- |
| Pause killing payment webhooks | Idempotent webhook handler + `webhook_events` dedupe table; Razorpay retries self-heal gaps | None |
| Uptime during dev | `health` edge function + external cron pinger ($0) | Remove pinger (optional) |
| Analytics DB growth | `analytics_events` + retention purge (`app.analytics_retention_days`, default 30) | Raise setting / flip `SUPABASE_TIER=pro` |
| Priority push limits | `priorityBroadcastEnabled` flag, hard-gated on `isProTier` | Set `PRIORITY_BROADCAST_ENABLED=true` |
| Rate limits / SLA | `AppConfig.supabaseTier` enum consulted by budget logic | `SUPABASE_TIER=pro` |

## 1. Canonical data model (migration 08)

### 1.1 Enums

| Enum | Values |
| --- | --- |
| `org_subscription_tier` | `basic`, `gold`, `platinum` |
| `subscription_status` | `trialing`, `active`, `past_due`, `canceled`, `expired` |
| `verification_method` | `digilocker`, `manual_web` |
| `digilocker_request_status` | `initiated`, `otp_sent`, `docs_fetched`, `verified`, `failed` |

### 1.2 Tables & ownership

| Table | Client access | Writes via |
| --- | --- | --- |
| `subscriptions` | SELECT own row (`auth.uid() = org_id`) or admin | service_role only (payment webhook) |
| `webhook_events` | none (RLS enabled, zero policies) | service_role only |
| `verification_requests` | SELECT own rows / admin | service_role only (edge functions) |
| `analytics_events` | SELECT own org's rows / admin | service_role only |

### 1.3 Key server functions

* `active_org_tier(org_id)` — returns live tier or NULL. **Gold badge and all
  paid-feature gating derive from this, never from `profiles.role`**, so plan
  changes never require role surgery.
* `caller_is_privileged()` — true for service_role JWT or admin profile.
* `guard_role_escalation()` trigger on `profiles` — registration lock:
  `admin`/`org_placeholder` roles and `is_verified` flips are only writable by
  service_role/admin (also closes the pre-prod audit gap where
  "Users can update own profile" exposed sensitive columns).
* `purge_old_analytics_events()` — retention job, free-tier DB-size control.

## 2. Phases & artifacts

| Phase | Deliverables | Status |
| --- | --- | --- |
| 0 Pre-flight (Free) | `id-verifications` bucket, audit checklist, `AppConfig` v4 flags + health pinger, Razorpay **test-mode** account | Mostly done — remaining: AI screening proxy move (→ V5 Phase A item A3); dislike/report-surge trigger legs (→ V5 Phase C sim proof-runs) |
| 1 Schema | `supabase/migrations/08_v4_monetization_schema.sql` | Done |
| 2 DigiLocker | Edge fns `digilocker-initiate` / `digilocker-finalize` (callback+finalize folded into one terminal function; mock provider auto-verifies until govt approval); `DigiLockerVerificationService` (simulation contract, `test/digilocker_service_test.dart`); manual upload web-only (`kIsWeb` gate in `uploadIDVerification`/`processIDVerification`); "Verify instantly with DigiLocker" CTA on `id_verification_screen.dart` | Done |
| 3 Subscriptions | `create-subscription-checkout` / `payment-webhook` (HMAC + idempotent dedupe) / `cancel-subscription`; `SubscriptionService` (`test/subscription_test.dart` 7/7); `OrgSubscriptionScreen`; `OrgTierBadge`; `SubscriptionException`; Right-of-Reply shipped as migration 10 + B11 (done) | Done |
| 4 Analytics | Migration `09_v4_analytics_rollups.sql` (`org_post_stats`, `org_fact_check_outcomes`, `org_analytics_summary` security_invoker views); `AnalyticsService` + trust score; `OrgAnalyticsDashboard` screen | Done |
| 5 Testing & docs | digilocker/subscription/analytics/right_of_reply/registration-lock tests all green; env-bound live verification pending migrations 08–10 | Done (code side) |

## 2b. Backlog — Phase 1–4 follow-ups (manual / deferred)

Items below are NOT code blockers for local v4 development but must be closed
before or shortly after release. Owner notes included.

**Dashboard / manual (user):**
- [x] **B1. ~~Apply migrations 08 + 09 + 10~~ DONE 2026-08-23** (`08_v4_monetization_schema.sql`, `09_v4_analytics_rollups.sql`, `10_v4_right_of_reply.sql` applied via SQL editor). **Migration 11 (storage policies) also applied 2026-08-23.**
- [x] **B2. ~~Create private `id-verifications` bucket~~ DONE 2026-08-23** — private bucket created; public-read policies verified blocked (audit checklist storage-RLS item also closed).
- [x] **B3. ~~Deploy edge functions~~ DONE 2026-08-23** — all five deployed (digilocker-initiate/finalize carry the `DIGILOCKER_ENABLED` kill-switch, off until V6).
- [x] **LIVE VERIFICATION 2026-08-23**: real OTP signup/login ✅ · ID upload from web (binary upload into per-user folder) ✅ · admin console approval past the registration-lock trigger ✅ · zero-retention purge path updated ✅ · **Gold upgrade → active subscription → badge rendering ✅** · **Right-of-Reply portal submit/publish ✅** · **Campaign Analytics dashboard loads on live data ✅** (CORS headers added to all client-facing functions during testing). Remaining live checks: dislike/report-surge trigger legs; webhook renewal events (first cycle).
- [x] **B4. ~~Close remaining pre-production audit checklist~~ MOSTLY DONE 2026-08-23**: storage RLS on bucket ✅ (migration 11 policies; upload + admin preview verified live); column-level write security ✅ (registration-lock trigger + live admin-approval path verified past it); remaining: AI screening proxy move (pre-launch) and full trigger proof-runs (dislike/report-surge legs).
- [x] **B5. ~~Schedule analytics retention purge~~ DONE 2026-08-23** (`purge_old_analytics_events()` verified; deletes only raw events past retention, returns deleted-row count).
- [ ] **B6. Apply for DigiLocker sandbox/API approval** — **DEFERRED TO V6** (2026-08-23 decision): the integration is fully mocked with error handling; manual verification stays the production path until go-live. Mobile manual-upload fallback auto-re-enables while credentials are unconfigured. **Safety:** both edge functions carry a `DIGILOCKER_ENABLED` kill-switch (reject 503 unless `'true'`), so they can be safely deployed before go-live without any self-verification risk. At V6 go-live: `supabase secrets set DIGILOCKER_ENABLED=true DIGILOCKER_CLIENT_ID=… DIGILOCKER_CLIENT_SECRET=… DIGILOCKER_BASE_URL=… DIGILOCKER_REDIRECT_URI=…` then redeploy both functions.
- [x] **B10. ~~Razorpay test account + webhook secret setup~~ DONE 2026-08-23.** Secrets: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `RAZORPAY_PLAN_GOLD`, `RAZORPAY_PLAN_PLATINUM`.
- [ ] **B8. Deeper eKYC XML parsing** in `digilocker-finalize` (name/DOB extraction, issuer validation) — **DEFERRED TO V6** with the go-live (B6); current check is envelope-presence only.

**Code follow-ups (next dev pass):**
- [x] **B9. ~~Verify admin flows against the new `guard_role_escalation` trigger~~ DONE (code side)**: audited — `approveVerification`/`rejectVerification` run under an admin JWT (`main.dart` routes only `role == admin` to the console) which `caller_is_privileged()` allows past the trigger; `AdminModerationService` touches only posts/reports (never sensitive profile columns). Regression guards pinned in `test/registration_lock_test.dart`. *Live DB verification still pending after B1.*
- [x] **B16. ~~Native deep-link bridge~~ DONE**: `app_links` added; `main.dart` `_bindAppLinks()` forwards cold-start and warm-start URIs into `DeepLinkHandler.instance.handleUri()`. Full DigiLocker callback path is now live-capable.
- [x] **B11. ~~Right-of-Reply portal~~ DONE**: migration `10_v4_right_of_reply.sql` (`right_of_replies` table, one per org+post, `draft|published|withdrawn`; RLS: insert/update gated on `active_org_tier() IS NOT NULL` + own posts; published replies public); `RightOfReplyService` (`test/right_of_reply_test.dart` 8/8); `RightOfReplyPortal` screen (queue of under_review/disputed org posts with compose/revise/withdraw); `OfficialReplyBanner` rendered publicly on flagged post cards; new `RightOfReplyException`.
- [x] **B12. ~~Wire v4 screens into navigation~~ DONE**: profile menu gains "Organization Plans" + "Campaign Analytics" tiles (party/partyMember roles); `FutureOrgTierBadge` rendered on org post-card headers.
- [x] **B13. ~~Razorpay Checkout SDK on client~~ DONE**: `razorpay_flutter` added; `RazorpayCheckoutService.openSubscriptionSheet()` opens the native sheet with `{checkoutId, keyId}` from real-mode checkout; wired into `OrgSubscriptionScreen._upgrade` (activation still webhook-driven; web/simulation gracefully skip). *Requires B10 keys to run live.*
- [x] **B14. ~~Register webhook endpoint in Razorpay dashboard~~ DONE 2026-08-23**: points to `<project>/functions/v1/payment-webhook`, subscribed to `subscription.*` events, `RAZORPAY_WEBHOOK_SECRET` set to match.
- [x] **B15. ~~Past-due / renewal UX~~ DONE**: `SubscriptionService.fetchStatus()` added; crimson "Payment issue detected" banner shown on `OrgSubscriptionScreen` when status is `past_due`.
- [ ] **B17. Real community entities** (V1-era gap surfaced during live testing): communities are display-name strings (`defaultCommunitiesList`), not DB rows — `profiles.community_id`/`posts.community_id` are UUID columns with nothing to reference. Fix: `communities` table (id UUID, name, ward metadata) + selector reads rows instead of constants + migration to backfill. **Interim guard shipped:** feed queries and community updates validate UUIDs and degrade gracefully (hyper-local falls back to broader; name-only selections stay local to the session). → **Scheduled as V5 Phase A item A1 (see roadmap).**

## 3. Client configuration flags (`lib/config.dart`)

```dart
AppConfig.supabaseTier            // 'free' (default) | 'pro'
AppConfig.isProTier               // bool
AppConfig.razorpayKeyId           // --dart-define=RAZORPAY_KEY_ID=rzp_test_...
AppConfig.isPaymentsConfigured    // checkout UI gate
AppConfig.priorityBroadcastEnabled // requires pro tier AND explicit opt-in
AppConfig.digilockerBaseUrl       // empty = mock provider / disabled on device builds
AppConfig.isDigilockerEnabled     // true in forceTestMode for tests
```

## 4. Pro Upgrade Runbook (v4.1 — first paying org)
> Executes only during **Alpha Phase E** (after V6 UI freeze) per the revised
> roadmap. All items below are configuration-only.

1. Supabase dashboard: upgrade project to Pro ($25/mo).
2. Razorpay: activate live account; set `--dart-define=RAZORPAY_KEY_ID=<live>`
   in edge function secrets and client build.
3. Set `--dart-define=SUPABASE_TIER=pro`.
4. Set `--dart-define=PRIORITY_BROADCAST_ENABLED=true`.
5. Raise retention: `ALTER DATABASE postgres SET app.analytics_retention_days = '365';`
6. Remove external cron pinger.
7. Verify `webhook_events` has no unprocessed rows (`processed_at IS NULL`)
   older than the pause window.

**Expected diff: env vars only. No schema, service, or widget changes.**

## 5. Risk register

| Risk | Mitigation |
| --- | --- |
| DigiLocker API approval lead time | Mock provider behind `isDigilockerEnabled`; subscriptions/analytics ship first |
| Free-tier project pause during webhook | Idempotent `webhook_events` log; Razorpay auto-retry |
| Failure to convert orgs to paid | 14-day trial + 1 free local broadcast push (roadmap mitigation) |
| DB growth past 500 MB free cap | Retention purge + rollup views carry the durable data |
