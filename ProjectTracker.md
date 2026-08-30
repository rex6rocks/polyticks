## Polyticks V1.0 (MVP Alpha) Master Project Tracker

_Use this master document to track the overall completion of the app, correlate
tasks to specific agents/roles, and document the current state and upcoming
roadmap milestones._

### Milestone Summary: MVP Alpha (v1.0) — **Completed & Verified**

| Epic / Feature                    | Task Description                                                           | Assignee / Lead         | Status   | Implementation Details & Artifacts                                                      |
| --------------------------------- | -------------------------------------------------------------------------- | ----------------------- | -------- | --------------------------------------------------------------------------------------- |
| **1. Environment & Config**       | Init Flutter project (Android/iOS) & Folder Structure                      | RooCode / Aider         | **Done** | `lib/main.dart`, `lib/models/`, `lib/screens/`, `lib/widgets/`, `lib/services/`         |
|                                   | React Web App & Vite Toolchain Setup                                       | AI Studio               | **Done** | `src/`, `package.json`, `vite.config.ts`, Tailwind CSS                                  |
|                                   | Supabase Client & Config Setup                                             | Cline                   | **Done** | `lib/config.dart`, `lib/core/supabase_client.dart`, `lib/supabase/client.ts`            |
| **2. Database & Security**        | PostgreSQL DB Schema (`profiles`, `posts`, `reactions`, `reports`)         | Antigravity             | **Done** | `schema.sql` (Tables, Enums, Foreign Keys, Triggers)                                    |
|                                   | PostgreSQL Row-Level Security (RLS) Policies                               | Antigravity             | **Done** | `schema.sql` (Read/Write auth checks, voting constraints)                               |
|                                   | ID Verifications Private Storage Bucket Config                             | Cline / Antigravity     | **Done** | Private bucket configuration with restricted admin access                               |
|                                   | Reaction Sync & User Triggers                                              | Antigravity             | **Done** | Auto-profile creation on signup & live reaction count triggers in `schema.sql`          |
| **3. Authentication & ID Flow**   | GoTrue Phone OTP Service                                                   | Cline                   | **Done** | `lib/services/auth_service.dart`, `lib/services/supabase_service.dart`                  |
|                                   | Phone Login & OTP Verification UI                                          | RooCode / Cline         | **Done** | `LoginScreen` & `OTPVerificationScreen` in Flutter & React                              |
|                                   | On-Device ID Image Compression (<150 KB)                                   | Cline                   | **Done** | `lib/services/image_compressor.dart` (Iterative JPEG compression)                       |
|                                   | ID Upload & Verification Request Flow                                      | Cline / RooCode         | **Done** | `IDVerificationService.dart`, `id_verification_screen.dart`, `IdVerificationScreen.tsx` |
| **4. UI & Core Components**       | Base Component Library (`PrimaryButton`, `CustomTextField`, `ReactionRow`) | RooCode / Aider         | **Done** | `lib/widgets/common_widgets.dart`, `lib/widgets/interactive_widgets.dart`               |
|                                   | Feed & Post Card Widgets (`PostCard`, `FeedCard`, `PollCard`)              | RooCode                 | **Done** | `lib/widgets/post_card.dart`, `lib/widgets/poll_widget.dart`, `src/components/`         |
|                                   | Dual Feed Navigation (Hyper-Local vs Broader Channels)                     | RooCode / Cline         | **Done** | `lib/screens/feed/feed_screen.dart`, `src/screens/FeedScreen.tsx`                       |
|                                   | Post Creation Modal with 280-char limit & Channel Picker                   | RooCode                 | **Done** | Embedded in Flutter feed + `src/components/CreatePostModal.tsx`                         |
|                                   | Party Profiles & Candidate Hubs                                            | RooCode                 | **Done** | `lib/screens/party/party_profile_screen.dart`, `src/screens/PartyProfileScreen.tsx`     |
| **5. Engagement & Interactivity** | Optimistic Reaction Engine (Like/Dislike toggle)                           | Cline                   | **Done** | `SupabaseService.dart`, `src/services/storageService.ts`                                |
|                                   | Community Ballot Poll Voting System                                        | RooCode / Cline         | **Done** | `PollWidget.dart`, `PollCard.tsx`, interactive voting handlers                          |
|                                   | Civic Comments & Audit Trail Logging                                       | Cline                   | **Done** | Edit history tracking and civic comment threads                                         |
| **6. Admin & Privacy Pipeline**   | Admin Verification Console UI                                              | RooCode                 | **Done** | `lib/screens/admin/admin_console_screen.dart`, `src/screens/AdminConsoleScreen.tsx`     |
|                                   | Verification Moderation (Approve/Reject)                                   | Cline                   | **Done** | Profile role upgrade to `verified_user` / `partyMember`                                 |
|                                   | Zero-Retention ID Auto-Purge on Decision                                   | Cline                   | **Done** | Immediate deletion of ID documents from storage upon review                             |
|                                   | Purge Audit Logging                                                        | AI Studio               | **Done** | Live purge record logs in `AdminConsoleScreen`                                          |
| **7. Data & Testing**             | Comprehensive Mock Data & Seed Profiles                                    | AI Studio               | **Done** | `lib/data/mock_data.dart`, `src/data/mockData.ts`                                       |
|                                   | Unit & Logic Test Suite                                                    | Antigravity / Cline     | **Done** | `test/` (Models, Auth, Post Logic, Mock Data, Feed verification)                        |
|                                   | 5-Stage Release Roadmap & Blueprint Specs                                  | Antigravity / AI Studio | **Done** | `blueprint.md`, `roadmap.md`                                                            |

---

### Milestone Status: Version 2.0 (Fact-Check & Trust Engine) — **Completed** (live DB contract checks A5/B3 & Groq smoke test C4 pending credentials)

> Verified against `supabase/migrations/02_v2_fact_checking_schema.sql`,
> `03_v2_rls_policies.sql`, `04_v2_triggers.sql` (dislike-threshold trigger
> proven live in `test/supabase_triggers_test.dart`),
> `07_v2_sla_auto_hide.sql`, the `FactCheckService` /
> `AIModerationService` / `AdminModerationService` service layers and the
> `FactCheckStatus` enum in `lib/models/models.dart`. Reconciled 2026-08-23
> per `pending/V2_COMPLETION_PLAN.md`.

| Epic / Feature         | Task Description                                                    | Assignee / Lead     | Status      | Notes                                                    |
| ---------------------- | ------------------------------------------------------------------- | ------------------- | ----------- | -------------------------------------------------------- |
| **v2.0 Fact Checking** | Automated Dislike Threshold Trigger (>60% dislikes)                 | Antigravity         | **Done**    | Implemented in `supabase/migrations/04_v2_triggers.sql`  |
|                        | Global State Management Spec (`FactCheckState` & `ModerationState`) | Antigravity         | **Done**    | Recreated at `docs/V2_STATE_MANAGEMENT_SPEC.md`          |
|                        | Verified Community Notes Submission UI                              | RooCode / Cline     | **Done**    | `FactCheckService`, `SubmitFactCheckModal` (widgets/, duplicate screens/ copy removed), verified-only gating + notes rendering via `CommunityNotesSection`; tests in `fact_check_service_test.dart` + `submit_fact_check_modal_test.dart` |
|                        | 24-Hour Moderation SLA Auto-Hide on Report Surge                    | Antigravity / Cline | **Done**    | `supabase/migrations/07_v2_sla_auto_hide.sql` (`evaluate_report_surge`, `sla_unhide_stale_reports`, `sla_events`, `admin_sla_breaches` view), admin wiring in `AdminModerationService`; tests in `test/sla_auto_hide_test.dart` (env-bound) |
|                        | Free-tier AI Text Screening Pipeline                                | AI Studio           | **Done**    | `AIModerationService` (Groq llama-guard-3-8b → HF → mock), fail-open outage semantics, identical-content cache + rolling budget guard; tests in `ai_moderation_failopen_test.dart`; Edge Function proxy roadmap noted in `lib/config.dart` |

---

### Milestone Status: Version 3.0 (Hyper-Local Clustering, Polls & Viral Sharing) — **Completed** (only manual T5.3 device unfurl check outstanding)

> Verified against `pending/V3_PHASE3_TESTING.md` (all phases checked,
> Phases 6–7 DoD/regression guards green as of 2026-08-22) and
> `supabase/migrations/06_v3_clustering_and_polls.sql`.

| Epic / Feature    | Task Description                                                   | Assignee / Lead | Status      | Notes                                                                                                                                                                                                                                                  |
| ----------------- | ------------------------------------------------------------------ | --------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **v3.0 Task 3.3** | Dynamic Social Preview Cards (`generate-share-card` Edge Function) | Cline           | **Done**    | `supabase/functions/generate-share-card/index.ts`; T4.1–T4.5 pass live (`test/share_card_edge_test.dart`)                                                                                                                                              |
|                   | Dual-Feed Query Logic (Hyper-Local vs Broader/National)            | Cline           | **Done**    | `feedFilterSpec()`/`applyFeedFilter()` in `lib/services/supabase_service.dart`; T1.1–T1.4 pass (`test/dual_feed_wiring_test.dart`)                                                                                                                     |
|                   | Optimistic Poll Voting Engine + DB Contract                        | Cline           | **Done**    | `voteInPoll()` optimistic/revert; T2.x pass (`test/poll_voting_test.dart`), T3.1–T3.4 live (`test/poll_db_contract_test.dart`); migration 06 RLS/triggers verified                                                                                     |
|                   | Share Payload + Deep Links + OG Meta (`share_plus`, `/post/:id`)   | Cline           | **Testing** | T5.1/T5.2 pass live (`test/share_payload_test.dart`, `src/deepLinks.ts`); only manual T5.3 WhatsApp/X unfurl check pending — crawler-grade unfurl may need prerendered head tags                                                                       |
|                   | Phase 6 DoD Sweep + Phase 7 Regression Guards                      | Cline           | **Done**    | `test/regression_guards_test.dart` 9/9 live; full suite at baseline 13 fails (zero regressions). ⚠️ Create private `id-verifications` bucket before launch (missing on project); dislike-threshold escalation leg auto-skips (email signup rate limit) |

## Pre-Production Release

## Polyticks V4.0 (Scale & Monetization) — Free-Tier First

_See `docs/V4_SPEC.md` for full spec, pro-ready seams, and the Pro Upgrade
Runbook. Launch strategy: ship entirely on Supabase FREE tier; Pro upgrade is
a post-release (v4.1) config-only update when the first org is ready to pay._

| Phase | Task | Status | Artifacts / Notes |
| ----- | ---- | ------ | ----------------- |
| **Phase 1** | Monetization & verification schema (migration 08) | **Done** | `supabase/migrations/08_v4_monetization_schema.sql`: `subscriptions`, `webhook_events` (idempotent dedupe), `verification_requests`, `analytics_events` (+retention purge); RLS service-role-write-only; `active_org_tier()`, `caller_is_privileged()`; registration-lock trigger (`guard_role_escalation`) closing the profiles column-security audit gap |
| **Phase 0** | AppConfig v4 pro-ready seams + feature flags | **Done** | `lib/config.dart`: `supabaseTier`/`isProTier`, `razorpayKeyId`/`isPaymentsConfigured` (test-mode), `priorityBroadcastEnabled` (pro-gated), `digilockerBaseUrl`/`isDigilockerEnabled` |
| **Phase 0** | Spec doc + Pro runbook | **Done** | `docs/V4_SPEC.md` |
| **Phase 2** | DigiLocker edge functions + `DigiLockerVerificationService` (mock provider) | **Done** | `supabase/functions/digilocker-initiate` + `digilocker-finalize` (mock mode auto-verifies until govt sandbox approval); `lib/services/digilocker_verification_service.dart` with simulation contract (`test/digilocker_service_test.dart` 5/5); manual upload gated web-only (`uploadIDVerification` / `processIDVerification` throw on real mobile builds); DigiLocker primary CTA added to `id_verification_screen.dart`; new `DigiLockerFlowException` |
| **Phase 3** | Razorpay checkout/webhook/cancel edge fns, upgrade UI, Gold badge, trial, priority push (flag off) | **Done** | `create-subscription-checkout` / `payment-webhook` (HMAC-verified + `webhook_events` idempotent dedupe) / `cancel-subscription` edge fns (mock mode until live keys); `lib/services/subscription_service.dart` simulation contract (`test/subscription_test.dart` 7/7); `OrgSubscriptionScreen` tier cards; `OrgTierBadge` widget; new `SubscriptionException`. **Right-of-Reply portal → backlog B11** |
| **Phase 4** | Analytics rollup views + B2B dashboard | **Done** | `supabase/migrations/09_v4_analytics_rollups.sql`: `org_post_stats`, `org_fact_check_outcomes`, `org_analytics_summary` (security_invoker views over posts/reactions/fact_checks — durable rollup layer survives analytics_events purge); `lib/services/analytics_service.dart` (`OrgAnalyticsSummary` + trust score) with simulation contract (`test/analytics_service_test.dart` 5/5); `lib/screens/org/analytics_dashboard.dart` (trust card, stat cards, outcome breakdown). Navigation wiring → backlog B12 |
| **Phase 5** | Tests: registration lock, analytics RLS + regression guard extensions | **Done (code side)** | `test/registration_lock_test.dart` 6/6 (B9 guards + B7 deep-link CSRF/parsing); digilocker/subscription/analytics tests green; full suite at baseline 13 fails, zero regressions. Live verification: OTP login, ID upload (web), admin approval past registration-lock trigger — all confirmed 2026-08-23 |
| **Phase 0** | Create private `id-verifications` bucket; close pre-prod audit checklist | **Mostly done 2026-08-23** | Bucket ✅ · storage policies (migration 11) ✅ · live upload/approve verified ✅. Remaining: AI screening proxy move; dislike/report-surge trigger legs |

### Backlog progress (see docs/V4_SPEC.md § 2b)
Done: **B1–B5, B7, B9–B14, B16** including live infrastructure setup and first
live verifications (OTP auth, ID upload web, admin approval past trigger).
Live fixes shipped during testing: auth screens wired to real OTP (were
mock-only), `is_verified` profile mapping, web-compatible ID upload with
per-user storage folders + signed-URL admin previews, UUID guards for mock ids.
Remaining code: **B11 follow-ups none · B17 community entities (new)**.
Remaining manual: B6/B8/B15-device-test (DigiLocker, deferred to V6) · AI proxy
move · dislike/report-surge trigger proof-runs · WhatsApp/X unfurl check.

### Pre-Production Release

### Audit Checklist (What You Need to Check Right Now)

- [x] **Column-Level Write Security (`profiles` Table):** ✅ VERIFIED 2026-08-23 — `guard_role_escalation` trigger (migration 08) blocks client writes to `is_verified`/`role`; live admin-approval path confirmed working via admin JWT.
- [x] **Storage Bucket Policies:** ✅ VERIFIED 2026-08-23 — private `id-verifications` bucket created with per-user-folder policies (migration 11); no public/anonymous access; upload + signed-URL admin preview confirmed live. *(Resolves the 2026-08-22 "bucket does not exist" finding.)*
- [ ] **Client-Side Key Separation:** Audit the Flutter mobile codebase to
      ensure the Supabase service_role key is never compiled into the client
      app and is strictly held in secure Edge Function environment variables.
      → **V5 Phase A item A2.**
- [x] **PostgreSQL Trigger Security:** ✅ VERIFIED 2026-08-23 — all V4 triggers
      and functions (migrations 08–10) declare `SET search_path = public`;
      earlier V1/V2 triggers to spot-check during the remaining live pass.

### Next Phases (revised roadmap — see roadmap.md)

> Strategy: complete design/architecture/business-integration layers + testing
> + UI finalization entirely in simulation mode; real-data activities wait for
> Alpha. Consolidated pending-task list: `pending/PENDING_TASKS.md`.

| Version | Phase | Scope | Status |
| --- | --- | --- | --- |
| V5.0 | **Phase A — Design & Architecture** | A1 B17 community entities (`communities` table, backfill, feed/poll/analytics rewiring) · A2 client key-separation audit · A3 AI screening proxy move | Not started |
| V5.0 | **Phase B — Business Integration (mocked)** | B1 billing/trial/webhook hardening in mock mode · B2 priority broadcast configurator UI · B3 eKYC parsing deepened vs sandbox fixtures · B4 v4.1 pro-ready seams as code | Not started |
| V5.0 | **Phase C — Full Test Pass** | C1 fix 13 baseline test failures · C2 dislike/report-surge trigger proof-runs in sim harness · C3 regression guards for B17 + new surfaces | Not started |
| V6.0 | **Phase D — UI Finalization** | D1 cross-platform (Flutter/React) design audit · D2 business walkthrough in simulation mode + implement changes · D3 UI freeze | Not started |
| Alpha | **Phase E — Real-Data Launch** | E1 live trigger proof-runs · E2 WhatsApp/X unfurl device checks · E3 live AI smoke test · E4 monetization go-live (v4.1 runbook) · E5 DigiLocker live go-live · E6 load testing & scaled infra · E7 store submissions / public launch | Not started (gated on UI freeze) |

Remaining manual items from earlier phases are absorbed into the table above:
DigiLocker device-test → E5 · AI proxy move → A3 · trigger proof-runs → C2/E1 ·
unfurl check → E2.
### Milestone Status: Version 4.1 (Representative Data Pipeline & Open Data Integration) — **Completed**

> Verified against `supabase/migrations/14_v4_1_representative_pipeline.sql`,
> `14b_v4_1_postgis_spatial.sql`, `RepresentativeService` and `SpatialService`
> service layers, and `representative_service_test.dart` passing 10/10 test cases.
> Reconciled 2026-08-27.

| Epic / Feature         | Task Description                                                    | Assignee / Lead     | Status      | Notes                                                    |
| ---------------------- | ------------------------------------------------------------------- | ------------------- | ----------- | -------------------------------------------------------- |
| **Phase A — DB Migrations** | Full DDL for representative tables and Pro-only spatial boundary tables | Cline               | **Done**    | Idempotent tables and GIST spatial columns configured      |
| **Phase B — ETL Infrastructure** | sync-parliament-stats Edge Function + Python ETL scripts           | Cline               | **Done**    | Ingests constituencies, representatives, ADR affidavits |
| **Phase C — Flutter Services** | RepresentativeService & SpatialService implementation             | Cline               | **Done**    | Handles simulation contracts + PostGIS resolution       |
| **Phase D — Dart Models** | Representative models definition & export                           | Cline               | **Done**    | Mapping structures for profile stats & affidavit history |
| **Phase E — UI Feed Widget** | Sticky RepresentativeCard widget + skeleton loader at feed top      | Cline               | **Done**    | Automatically displays hyper-local representative card    |
| **Phase F — UI Profile Screen** | Representative profile & claiming screens                          | Cline               | **Done**    | Identity & subscription gating on claim flow            |
| **Phase G — Edge Function** | Atomic claim-representative endpoint                               | Cline               | **Done**    | JWT validated secure claiming transaction                |
| **Phase H — AppConfig** | Feature flags additions                                             | Cline               | **Done**    | Gating spatial, Digital Sansad and representative data   |
| **Phase I — Tests**     | Unit & service testing suite                                        | Cline               | **Done**    | 10/10 mock-mode verification test cases fully passing    |
