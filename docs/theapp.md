# The App — Polyticks, Version by Version

A business-perspective summary of what each version of Polyticks delivers.
Written for stakeholders and as a handoff briefing for an incoming dev team:
no code specifics, but concrete enough to know exactly what exists, how it
behaves, and where the boundaries are.

---

## Development Strategy (revised)

The platform is not live yet. The plan therefore completes **the entire design,
architecture, and business integration layers first** — all developed and
proven against the offline mock/simulation contract — followed by full test
coverage and UI finalization with business sign-off. Activities that require
real data (monetization go-live, live credentials, load testing, real
communities, store release) are consolidated into **Version Alpha (Phase E)**
and begin only after UI freeze.

| Version | Focus |
| --- | --- |
| V5.0 | Phases A/B/C — architecture completion (B17 communities, security audits), mocked business-integration completion, full test pass |
| V6.0 | Phase D — UI finalization with business sign-off and freeze; DigiLocker go-live staged |
| Alpha | Phase E — real-data launch activities: monetization, live triggers, unfurl checks, load testing, store release |

---

## Version 1.0 — MVP Alpha: The Civic Foundation (Completed & Verified)

V1.0 establishes the platform's core premise: a phone-verified civic network
where citizens, party members, and parties interact in a structured,
privacy-respecting environment.

### Identity & Trust at the Door

* Sign-in is phone-number based with one-time password verification — no email
  passwords, no anonymous accounts.
* Citizens can volunteer for identity verification by uploading a government ID
  directly from their phone; images are compressed on-device before upload to
  keep the flow fast and cheap on mobile data.
* Privacy is engineered in, not bolted on: identity documents are deleted
  immediately after a decision is made (zero-retention policy), every purge is
  logged for audit, and the documents live in a storage area inaccessible to
  the public.

### The Civic Feed

* A dual-channel feed separates **Hyper-Local** neighbourhood discussions from
  **Broader** community-wide ones, so local issues don't drown in national
  noise.
* Posting is deliberately constrained (short-form, character-limited) to favour
  substance over volume.
* Posts support like/dislike reactions that update instantly, community ballot
  polls, and threaded comments with edit-history tracking for accountability.
* Interaction rules (updated): Janta and Party Members can like/dislike/comment
  on ALL parties' posts; Party (official) accounts cannot react to their own
  org's posts. Party polls remain exclusive to that party's members. Members
  auto-follow their own party and cannot unfollow it while a member. Nobody can
  follow themselves, and no member can edit their own hierarchy role — only
  higher tiers (ultimately the party official account) can assign/revoke roles.

### Structure & Roles

* Distinct roles for citizens, party members, and official party accounts, so
  readers always know who is speaking — a citizen, a representative, or the
  party itself.
* Party profiles and candidate hubs give political organisations an official
  presence rather than unverified fan pages.

### Platform Characteristics

* Ships as both a mobile app and a web app sharing one backend and one data
  model.
* Row-level security enforced at the database: users can only ever read and
  modify what their role permits, independent of the app itself.
* An admin console handles verification decisions with full audit logging.
* A complete offline simulation mode allows the entire product to be explored
  and tested without touching production infrastructure.

**Handoff note:** V1 is stable and verified end-to-end. Its known pre-launch
gaps are operational, not feature gaps — see the pre-production audit checklist
in `ProjectTracker.md` (storage bucket creation, column-level write security
review, key separation).

---

## Version 3.0 — Hyper-Local Clustering, Polls & Viral Sharing (Completed)

Note: V3 shipped between V1 and V2 and focuses on reach and engagement —
making content locally relevant, participatory, and shareable.

### Hyper-Local Clustering

* Content is clustered into geographic communities, and feed queries are
  channel-aware: hyper-local feeds show only the reader's community;
  broader feeds aggregate across them. This gives every neighbourhood its own
  public square instead of one undifferentiated timeline.

### Participatory Polling

* Community ballot polls gained a full voting engine with instant optimistic
  feedback (votes appear immediately, safely reverting if the backend rejects
  them), backed by database-enforced rules: one vote per person per poll,
  verifiable tallies, and security policies proven against a live database.

### Viral Sharing & Deep Links

* Any post can be shared outside the app (WhatsApp, X, etc.) with a
  dynamically generated social preview card rendered server-side, so shared
  links look credible and informative in chat apps and timelines.
* Shared links deep-link straight back into the specific post inside the app.
  One manual check remains outstanding: verifying rich link unfurl behaviour
  on real devices via WhatsApp/X, since some crawlers may need prerendered
  page metadata.

### Release Confidence

* Dedicated regression-guard test suite proving V3 features don't interfere
  with earlier behaviour; the full suite runs at the recorded baseline with
  zero regressions.
* Live database contract tests confirm polling rules and share-card generation
  behave identically in production as they do in tests.

---

## Version 2.0 — Fact-Check & Trust Engine (Completed)

V2.0 turns Polyticks from a discussion platform into a self-moderating civic
trust platform. Citizens can now collectively flag unreliable content, trusted
members can attach verified context to it, and the platform escalates or hides
problematic posts automatically — with human oversight preserved at every
critical decision point.

### 1. Community Trust Signals (automated content escalation)

When a post receives significant negative engagement (a high share of dislikes
across a meaningful number of voters), the system automatically places it
"under review" — no moderator needs to spot it first. This is live and proven
against a real database.

### 2. Community Notes (verified-citizen fact-checking)

Only citizens who have completed identity verification can contribute.
Verified members can attach explanatory context and source links to posts that
are under review; other verified members can vote those notes up or down. When
a note earns strong community backing, the post itself is promoted to
"verified context" status — misinformation gets corrected in place rather than
just deleted. Unverified users are clearly prompted to verify instead of being
silently blocked, and abuse is capped (max 5 notes per user per day). Notes
render directly beneath flagged posts, including tappable source links, with
vote/retract controls.

### 3. Automatic Hiding on Report Surges

If a post accumulates 5 or more user reports within 24 hours, it is hidden
from the feed immediately and stamped as auto-hidden, with an audit record of
exactly why and when. Key safeguards built in: hiding is one-way until a human
decides (nothing auto-un-hides), repeat surges on an already-hidden post cause
no duplicate actions, and a scheduled audit sweep flags cases where reports
were all handled more than a day ago but no admin decision was ever made —
surfaced in a dedicated admin breach queue so nothing falls through the cracks.

### 4. Admin Moderation Console (upgraded decision workflow)

Admins see flagged and auto-hidden posts together with report counts and how
long a decision has been overdue. Approving a post restores it publicly and
closes out its reports; rejecting keeps it hidden with a timestamped, logged
reason. Silent deletion of reported content has been removed — every rejection
is traceable.

### 5. AI Content Screening (hardened for production economics)

Every post is screened by an AI safety model before publication. Two important
behavioural guarantees:

* **Posting never breaks because of the AI.** If the screening provider is
  down, times out, or hits its budget, posts are allowed through and the event
  is logged — a free-tier outage can never silence the platform.
* **Cost control.** Identical content is only screened once, and a rolling
  hourly cap keeps usage far below the free-tier daily allowance, so scaling
  traffic cannot produce surprise costs.

The API key currently ships inside the app build, which is acceptable for the
alpha; moving screening behind a server proxy is scheduled as **V5 Phase A**
(item A3), before any real-data activity begins.

### 6. Quality Assurance & Documentation

* Automated test coverage added across the new submission UI, moderation
  workflows, AI failure handling, and cross-feature interference between the
  dislike and report-surge triggers.
* Full regression suite verified: zero new failures against the recorded
  baseline.
* Project tracker reconciled to reflect reality (v2.0 marked Completed), and a
  previously missing state-management specification was recreated.
* Two items remain intentionally open, both blocked only on credentials, not
  on work: (a) live-database proof runs of the new triggers, and (b) one real
  AI smoke test once an API key is supplied.

**Bottom line:** with V2.0, all three trust-engine feature gaps are closed.
The platform now has an end-to-end pipeline — community signals detect →
verified citizens explain → automation contains → admins decide — with
auditability at each step.

---

## Version 4.0 — Scale, Trust Automation & Monetization (Completed — code complete; launch-gated on credentials)

V4.0 removes the platform's biggest scaling bottleneck (humans reading ID
documents) and turns political organisations into paying customers — while
deliberately launching on free infrastructure and deferring paid upgrades
until the first real customer arrives.

### Instant Identity Verification (built in V4.0; live go-live deferred to V6)

* Citizens on mobile will be able to verify their identity **instantly** through
  DigiLocker — the government digital identity service — by approving a single
  consent request in their own DigiLocker app. No document is ever uploaded,
  stored, or seen by anyone: verification happens against the government
  record directly.
* The flow runs as a three-step conversation between the app and our server:
  start a request → user consents at DigiLocker → the app receives a secure
  call-back that is validated against tampering before verification is
  granted. The full path is built and tested end-to-end against a simulated
  DigiLocker that behaves identically — going live later requires only
  credentials, not new work (**go-live deferred to V6**; see roadmap).
* Until then, manual document upload remains the production verification path
  on **all platforms** — the mobile upload restriction lifts automatically
  while DigiLocker credentials are unconfigured, and the instant-verification
  button stays hidden.

### Paying Organisations: Subscriptions

* Political parties and NGOs can upgrade to **Gold or Platinum** monthly plans,
  starting with a 14-day free trial. Upgrading unlocks:
  * a visible **verification badge** next to everything the organisation posts
    (readers can tell an official, paying voice from an impostor page);
  * the **Right of Reply** portal (below);
  * the campaign analytics dashboard (below);
  * reserved access to priority push broadcasts once infrastructure scales.
* Payments run through Razorpay. Payment confirmations arrive via signed
  server notifications that are verified and de-duplicated, so a missed signal
  during an outage self-heals when the provider retries — no organisation can
  silently lose its subscription status, and none can gain one without paying.
* Cancellation, failed-renewal warnings, and re-subscription are handled in-app;
  organisations always see exactly which plan they're on.
* Registration is locked at the database level: nobody can sign up or upgrade
  themselves into an administrative or official role through the app, and
  verification status can only ever be changed through privileged channels.

### Right of Reply (paid-tier accountability feature)

* When an organisation's content comes under fact-check scrutiny, the
  organisation gets a dedicated portal to publish an **official statement**
  alongside the community's context — revise it or withdraw it anytime.
* This is a monetised accountability feature: only Gold/Platinum organisations
  can respond, enforced at the database itself, not just in the app. Published
  statements appear publicly beneath the disputed post, so disputes become a
  two-sided record instead of a one-sided flagging.

### Campaign Analytics Dashboard (B2B)

* Organisations get a private dashboard showing how their content performs:
  post volumes, likes vs dislikes with a dislike ratio, recent activity, how
  many fact-checks were raised against their content and how each was resolved,
  and a plain-language **Crowd Trust Score** — the share of judged posts that
  ended clean or with accepted community context.
* Every organisation can only ever see its own numbers, enforced at the data
  layer. Analytics history is designed to survive aggressive cleanup of raw
  event data, keeping storage costs flat as traffic grows.

### Safety & Integrity Hardening (cross-cutting)

* A database-level guard now blocks any attempt by ordinary users to grant
  themselves admin status, official roles, or verification — closing a known
  pre-launch audit item, while keeping legitimate admin workflows working.
* Deep links are validated against session tampering: a call-back link that
  doesn't match the request that started it is rejected rather than trusted.

### Launch Economics (deliberate strategy)

* Everything above ships on **free-tier infrastructure**. The paid upgrade to
  professional infrastructure happens in a small follow-up update — triggered
  when the first organisation actually pays — and requires configuration
  changes only, no rebuilding. All the seams for that upgrade are already in
  place and documented as a step-by-step runbook.

**Bottom line:** V4.0 converts Polyticks from a cost centre into a product with
a revenue engine ($1k–$5k MRR target), removes its last manual-scaling
bottleneck, and hardens role security — with every feature tested offline and
ready to switch live as soon as external credentials arrive.

---

## Where the Product Stands Now

| Version | Theme                        | Status     | Open items |
| ------- | ---------------------------- | ---------- | ---------- |
| V1.0    | Civic foundation (identity, feed, roles) | Completed & verified | Pre-launch operational checklist (bucket, key separation, write-security review) |
| V3.0    | Local relevance, polls, viral sharing | Completed | One manual device unfurl check |
| V2.0    | Fact-check & trust engine    | Completed  | Credential-blocked live proofs + AI smoke test |
| V4.0    | Instant verification, subscriptions & monetization | **Completed & live-verified** | Only cross-version pre-launch ops remain (AI proxy move, trigger legs, unfurl check) + backlog B17 community entities |

---

## Pre-Launch Manual Checklist (everything left to execute outside the codebase)

All engineering work for V1–V4 is complete. What remains is account setup,
credential provisioning, and dashboard actions that only a human with access to
the external services can perform. Ordered roughly by priority.

### Supabase Dashboard ✅ DONE 2026-08-23

1–5. ~~Migrations 08+09+10 applied · private `id-verifications` bucket created ·
   storage policies added (migration 11) · all five edge functions deployed
   (DigiLocker ones kill-switched) · analytics retention verified.~~

**Live verification progress (2026-08-23):** real OTP signup/login ✅ · ID upload
from web with per-user folder storage ✅ · admin console approval past the new
registration-lock trigger, with zero-retention purge path updated ✅ ·
**paid upgrade live: Gold trial activated with badge rendering on posts ✅** ·
**Right-of-Reply portal publish flow ✅** · **Campaign Analytics dashboard on
live data ✅** (CORS support added to all client-facing functions during testing).
Remaining live checks: dislike/report-surge trigger proof-runs; webhook renewal
events at first cycle.

**Fixes made during live testing:** auth screens wired to real Supabase OTP
(were mock-only since V1 — wrong codes now rejected properly); profile
`is_verified` now mapped so the ID-verification gate actually fires; web-compatible
ID upload (binary upload into a per-user folder, replacing broken public-URL
admin previews with signed URLs); community names guarded against UUID columns
pending proper community entities (backlog B17).

### DigiLocker / Government (deferred to V6 — no launch dependency)

6. **Apply for DigiLocker API sandbox access** whenever convenient; the
   go-live itself is deferred to V6. Until credentials are configured, the
   built-in simulator covers development and **manual ID verification remains
   the production path on all platforms** (the mobile fallback re-enables
   automatically while DigiLocker is unconfigured).
7. At V6 go-live: add the client credentials as edge-function secrets and
   deepen the identity-response parsing (currently validated at envelope
   level only).

### Razorpay / Payments ✅ DONE 2026-08-23

8–10. ~~Account created (test mode), keys/secrets set · Gold & Platinum plans
   created · payment webhook registered for all `subscription.*` events.~~

### Security & Architecture (→ V5 Phase A)

11. **AI screening proxy move** — API key currently ships inside the app build
    by design; scheduled as V5 Phase A item A3 (architecture work, no real data
    required).
12. ~~Column-level write security~~ ✅ verified live — registration-lock trigger
    blocks client writes; admin approval path confirmed working past it.
13. **Client-side key separation audit** — V5 Phase A item A2.

### Test Coverage (→ V5 Phase C)

14. **Live-database proof runs of the V2/V4 triggers** — identity/subscription/
    right-of-reply schema already verified; dislike & report-surge legs will be
    proven in the offline simulation harness during Phase C, then re-stamped on
    production during Alpha (E1).

### UI Finalization (→ V6 Phase D)

15. Cross-platform design audit + business walkthrough of the full app in
    simulation mode; all recommended changes implemented before UI freeze.

### Real-Data Activities (→ Alpha Phase E — only after UI freeze)

16. WhatsApp/X rich-link unfurl spot check (E2) · live AI smoke test (E3) ·
    Razorpay live keys / monetization go-live via v4.1 runbook (E4) ·
    DigiLocker live go-live incl. real-device call-back test (E5) · load
    testing & scaled infrastructure (E6) · store submissions / public launch (E7).

---

An incoming dev team should start with `ProjectTracker.md` (authoritative task
status), this document (product intent), `docs/V4_SPEC.md` (V4 specification,
pro-ready seams, upgrade runbook), and the pre-production audit checklist before
any public release.
