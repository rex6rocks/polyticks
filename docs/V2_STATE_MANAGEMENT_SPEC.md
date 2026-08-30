# Polyticks V2 — State Management Spec (Fact-Check & Trust Engine)

> Recreated 2026-08-23 per Task D2 of `pending/V2_COMPLETION_PLAN.md`
> (the original file was referenced by `ProjectTracker.md` but missing).

## 1. Canonical status model

`FactCheckStatus` (client: `lib/models/models.dart`; DB enum:
`public.fact_check_status` in migration 02) is the single source of truth for
a post's moderation state. Values, in escalation order:

| Value              | Set by                                             | Meaning                                   |
| ------------------ | -------------------------------------------------- | ----------------------------------------- |
| `none`             | default                                            | No community signal                       |
| `under_review`     | dislike-threshold trigger (`04_v2_triggers.sql`)   | >60% dislikes @ ≥25 votes                 |
| `verified_context` | note-promotion trigger (`recalculate_fact_check_votes`, net score ≥10) or admin approve | Community context accepted |
| `disputed`         | admin decision                                     | Requires admin resolution                 |
| `auto_hidden`      | report-surge trigger (`07_v2_sla_auto_hide.sql`)   | ≥5 reports/24h; hidden until admin action |

## 2. State transition rules

* **Monotonic escalation:** triggers never downgrade. `under_review` may move
  to `verified_context` / `disputed` / `auto_hidden`; terminal states
  (`verified_context`, `disputed`, `auto_hidden`) are only left by an explicit
  admin action (`AdminModerationService.approveContent`).
* **Auto-hide is sticky:** nothing in the DB auto-un-hides.
  `sla_unhide_stale_reports()` only records `sla_breach` audit events into
  `sla_events` (surfaced via the `admin_sla_breaches` view); visibility is
  restored exclusively by an admin approve.
* **Cross-trigger independence:** the dislike trigger (04) and surge trigger
  (07) never interfere — both guard on current status before writing
  (regression-guarded in `test/sla_auto_hide_test.dart`).

## 3. Client-side ownership

| State slice            | Owner                                    | Notes |
| ---------------------- | ---------------------------------------- | ----- |
| Post list / feed       | `SupabaseService` + `mock_data.dart`     | Hidden posts filtered by RLS (`is_hidden = false`) and simulation filter |
| Per-post fact-check UI | `PostCard` widget                        | Renders banner (`underReview`), promoted context (`verifiedContext`) and `CommunityNotesSection` (fetched live via `fetchNotesForPost`) |
| Note submission        | `SubmitFactCheckModal`                   | Verified-only gate in `PostCard._showPostOptions`; domain exceptions
(`VerificationRequiredException`, `RateLimitExceededException`,
`DuplicateVoteException` from `lib/core/exceptions.dart`) surfaced as friendly
snackbars |
| Moderation queue       | `AdminModerationService`                 | `fetchFlaggedPosts()` enriches rows with `report_count` and `sla_breach_age_hours`; `approveContent` restores + resolves reports, `rejectContent` keeps hidden + logs |
| AI screening           | `AIModerationService` (pre-insert at `createPost`) | Fail-open on outage; identical-content cache + rolling free-tier budget |

## 4. Testing contract

* Simulation mode (`AppConfig.forceTestMode = true`) mirrors DB semantics for
  all service-layer transitions (`test/fact_check_service_test.dart`).
* Live-DB trigger proofs are env-bound (`SUPABASE_TEST_URL` /
  `SUPABASE_TEST_PUBLISHABLE_KEY`): `test/supabase_triggers_test.dart`,
  `test/sla_auto_hide_test.dart`.
