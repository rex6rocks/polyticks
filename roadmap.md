# Polyticks — Release Roadmap (Revised)

> **Development strategy (revised):** the product is NOT live yet. All versions
> up to and including V6 complete the entire design, architecture, and business
> integration layers — developed and proven entirely against the mock/simulation
> contract — plus testing and UI finalization with business sign-off. Activities
> that need real data (monetization go-live, load testing, real communities,
> live credentials) are consolidated into **Version Alpha** and happen only
> after UI freeze.

```
┌─────────────────────────────────────────────────────────────────────────┐
│ RELEASE PROGRESSION                                                     │
│                                                                         │
│  [ v1.0 MVP Alpha ]  ──►  [ v2.0 Fact-Check Engine ]                     │
│  - Android Only           - Community Notes                             │
│  - Manual ID Upload       - Like/Dislike Triggers                       │
│  - X/Twitter Ingestion    - 24h SLA Auto-Hide                           │
│                                      │                                  │
│                                      ▼                                  │
│  [ v5.0 Enterprise ] ◄──  [ v4.0 Scale & Monetize ] ◄── [ v3.0 Local ]  │
│  - Org Livestreaming      - DigiLocker Automated ID     - iOS Release   │
│  - Live Q&A Townhalls     - Paid $10-$50/mo Subscriptions- Dual Feeds    │
│  - AI Auto-Summaries      - B2B Analytics Dashboard     - Local Polls   │
│  - Phases A/B/C (design,                                                │
│    integration, tests)                                                  │
│            │                                                            │
│            ▼                                                            │
│  [ v6.0 Finalize & Go-Live Ready ] ──►  [ ALPHA Real-Data Launch ]       │
│  - Phase D: UI finalization        - Phase E: monetization go-live,     │
│    + business sign-off + freeze      live triggers, unfurl checks,       │
│  - DigiLocker credentials-only       load testing, store release         │
│    switch-on prepared                                                      │
└─────────────────────────────────────────────────────────────────────────┘
```

## VERSION 1.0 — MVP ALPHA (Proof of Concept & Seed Feed) — ✅ Completed & Verified
*   **Primary Goal:** Validate the core UI, feed performance, and manual verification pipeline at $0 cost with a small test group (50–100 users).
*   **Platform Target:** Android APK / Play Store Closed Internal Track.
*   **Tech Stack:** Flutter (Android), Supabase Free Tier, Vercel Free.
*   **Key Features:**
    *   Basic Auth with Phone OTP (via Supabase Auth).
    *   On-device ID compression (<150 KB) with manual admin approval.
    *   Read/Write Feed Engine with universal Like/Dislike buttons.
    *   Placeholder Org Accounts seeded via RSS/X API.
    *   Basic in-app block, mute, and reporting.
*   **Financial Strategy & Exit:** $0/month infrastructure cost. Exit criteria: 100 verified users onboarded; zero database memory leaks.

## VERSION 2.0 — THE TRUST & FACT-CHECK ENGINE — ✅ Completed
*   **Primary Goal:** Deploy the crowd-sourced fact-checking system and enforce store-compliant content moderation without censoring speech.
*   **Key Features:**
    *   "Community Notes" where verified users attach sources.
    *   Dislike Trigger Mechanism (>60% dislikes triggers banner).
    *   Reputation-Weighted Voting preventing unverified users from downvoting or submitting notes.
    *   AI Safety pipeline with 24-Hour SLA Auto-Hide for reported content.
*   **Exit Criteria:** Zero app store policy rejections; active fact-checking loop on >20 posts without brigading.

## VERSION 3.0 — HYPER-LOCAL CLUSTERING & iOS EXPANSION — ✅ Completed
*   **Primary Goal:** Launch the dual-feed architecture and achieve viral organic growth in physically clustered groups.
*   **Key Features:**
    *   Dual-Feed Navigation UI toggling between Hyper-Local and Broader feeds.
    *   Tamper-proof Local Community Polls for verified members.
    *   Claimable Org Accounts for official reps.
    *   Viral Claim Sharing creating dynamic image previews for social networks.
*   **Exit Criteria:** Onboard 5–10 distinct gated communities or campus groups.

## VERSION 6.0 — UI FINALIZATION & GOVERNMENT ID GO-LIVE PREP
*   **Primary Goal:** Freeze the product surface with business sign-off and
    stage the credentials-only DigiLocker switch-on.

### Phase D — UI Finalization (with business sign-off)
*   **D1. Cross-platform design audit** — Flutter mobile + React web component
    parity; consistent empty states, error states, and loading skeletons.
*   **D2. Business walkthrough** — stakeholders explore the full app in
    simulation mode; all recommended changes collected and implemented here.
*   **D3. UI freeze** — after sign-off, changes are bug fixes only. This is the
    gate for Version Alpha.

### DigiLocker Government ID Go-Live (credentials-only, staged here / executed in Alpha)
*   **Already built (V4.0):** initiate/finalize edge functions, client service,
    deep-link call-back with CSRF validation, mock provider, error handling;
    eKYC parsing deepened in V5 Phase B.
*   **Switch-on steps (executed during Alpha):** obtain sandbox approval → set
    `DIGILOCKER_ENABLED=true` + `DIGILOCKER_CLIENT_ID/_SECRET/_BASE_URL/`
    `_REDIRECT_URI` secrets and redeploy both functions → real-device call-back
    test.
*   **Exit Criteria:** >90% of new verifications completing instantly via
    DigiLocker; manual queue reserved for web-only edge cases.

## VERSION ALPHA — REAL-DATA LAUNCH ACTIVITIES (Phase E)
> Begins only after Phase D UI freeze. First time real users, real money,
> real credentials, and production load enter the picture.
*   **E1. Live trigger proof-runs** — dislike/report-surge legs re-run against
    the production database to formally stamp V2/V4 live verification.
*   **E2. WhatsApp/X rich-link unfurl device checks** — V3 leftover; add a
    prerendered/SSR head layer for `/post/:id` if crawlers need it.
*   **E3. Live AI smoke test** — one flagged + one clean phrase through the
    screening proxy once `GROQ_API_KEY` is provisioned server-side.
*   **E4. Monetization go-live (v4.1 runbook)** — Supabase Pro upgrade, Razorpay
    live keys, `SUPABASE_TIER=pro`, priority broadcasts enabled, retention
    raised. Runbook: `docs/V4_SPEC.md` §4.
*   **E5. DigiLocker live go-live execution** — credentials set per V6 steps;
    mobile upload auto-restricts to web; real-device call-back test.
*   **E6. Load testing & scaled infrastructure** — prerequisite for v5.0
    enterprise features on real traffic.
*   **E7. Store submissions & public launch** — Play Store public track,
    App Store submission with EULA/moderation terms.

## DEPENDENCY & RISK MATRIX
| Version | Main Operational Risk | Mitigation Strategy |
| :--- | :--- | :--- |
| **v5.0-A** | B17 migration breaks feeds/polls | Backfill migration + regression guards before rewiring; UUID guards remain until proven |
| **v5.0-B/C** | UI polish masks logic bugs | Fix 13-failure baseline before Phase D |
| **v6.0-D** | Endless business change requests | Time-boxed walkthrough; changes batched once, then freeze |
| **Alpha-E** | Real-money/payment webhook failures at scale | Idempotent `webhook_events` log; Razorpay auto-retry |
| **Alpha-E** | High video bandwidth and egress costs (v5 features) | Restrict livestreaming strictly to paying Org accounts; load-test first |
| **v2.0/v4.0 legacy** | Brigading on fact-checks | Verified-only fact-checking; RLS rate limits |
