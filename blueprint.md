# Polyticks — Comprehensive Product & Business Blueprint

## 1. Executive Vision & Strategic Positioning
### 1.1 Mission Statement
To build a trusted, bot-free, hyper-local civic and political platform that balances freedom of expression with accountability tracking through crowd-sourced fact-checking, without censoring user discourse.

### 1.2 Core Philosophies
*   **Censorship-Free Engagement:** Posts are never deleted or shadow-banned purely for political stance or factual disagreement.
*   **Accountability Through Context:** Misinformation is countered with verifiable context and crowdsourced community notes rather than deletion.
*   **Hyper-Local Clustering:** Political discourse is most effective when grounded in local physical proximity (gated communities, neighborhood associations, municipal districts) before scaling to national channels.
*   **Zero-Bot Zero-Tolerance:** Complete prohibition of automated bot accounts using multi-layered identity verification.

---

## 2. Account Hierarchy & User Roles
The platform operates on a strict Role-Based Access Control (RBAC) model implemented at the database layer (PostgreSQL Row-Level Security in Supabase):

*   **Basic (Unverified User) [Free]:** Can view feeds, follow local/national channels, and cast basic likes/dislikes. Restricted from posting original content, downvoting fact-checks, or submitting claims.
*   **Verified User [Free — ID Required]:** Full posting rights, ability to submit and vote on Community Fact-Checks, access to local gated community polls, and immunity from bot-detection flags.
*   **Placeholder Organization Account [Internal Free]:** Automated, read-only accounts representing local political entities, government bodies, or NGOs. Feeds are populated via verified public APIs (e.g., Twitter/X RSS) to ensure feed activity prior to official onboarding.
*   **Paid Organization Account [$10–$50 / month]:** Verified with a Gold Badge. Grants access to broadcast push notifications, official "Right-of-Reply" portals on disputed claims, campaign analytics, and streaming privileges (Phase 2). Standard user registration flows explicitly block signing up directly into this tier.

---

## 3. Technical Architecture & Infrastructure
### 3.1 Tech Stack Architecture ($0 / Low-Cost Tier)
*   **Client Layer:** Flutter Cross-Platform App (iOS & Android) featuring on-device image compression and hash generation.
*   **Backend (Supabase):** PostgreSQL Database with Row-Level Security (RLS), GoTrue Authentication (OAuth + Phone OTP), Storage Buckets (Private for ID docs / Public for post media), and Edge Functions (Database Triggers & Webhooks).
*   **AI Screening & Fact-Check:** Grok AI API / Groq Inference or Hugging Face Open-Source Models.
*   **Web & Admin Dashboard:** Vercel or Netlify free hosting running a Flutter Web Admin Console.

### 3.2 Core Database Schema
*   **profiles Table:** `id (UUID)`, `phone_number (Text)`, `is_verified (Boolean)`, `verification_status (Enum)`, `role (Enum)`, `community_id (UUID)`, `created_at (Timestamp)`.
*   **posts Table:** `id (UUID)`, `author_id (UUID)`, `channel_type (Enum)`, `community_id (UUID)`, `content (Text)`, `media_urls (Text Array)`, `like_count (Integer)`, `dislike_count (Integer)`, `is_hidden (Boolean)`, `fact_check_status (Enum)`, `created_at (Timestamp)`.
*   **fact_checks Table:** `id (UUID)`, `post_id (UUID)`, `submitted_by (UUID)`, `context_note (Text)`, `source_links (Text Array)`, `upvotes (Integer)`, `downvotes (Integer)`, `status (Enum)`.

---

## 4. Functionality & Core Product Mechanics
### 4.1 Hyper-Local vs. Broader Navigation (Dual Feed UI)
*   **Hyper-Local Tab:** Uses user-selected or verified residency IDs to place users into specific gated communities, university campuses, or municipal wards. Posts here affect only local community members.
*   **Broader Channel Tab:** National and state-level political feeds. Allows filtering by specific topics (e.g., Economy, Healthcare, Local Infrastructure).

### 4.2 Dislike Mechanism & Automated Fact-Check Flagging
*   **Uncensored Dislikes:** Every post features visible Like and Dislike counts.
*   **Automated Trigger Threshold:** When a post receives a high dislike-to-like ratio (e.g., >60% dislikes with a minimum of 25 total votes) from Verified Users, an Edge Function automatically updates `posts.fact_check_status` to `'under_review'`.
*   **Queueing:** This triggers a prominent "Request Fact-Check Context" banner under the post, prompting verified community members to attach sources.

### 4.3 Anti-Brigading & Rate-Limiting Controls
*   **Row-Level Security (RLS):** Database limits 1 vote per user per post.
*   **Account Age & Status Gates:** Unverified or newly created accounts (<48 hours) cannot trigger fact-check flags or participate in high-volume downvoting.
*   **Device Fingerprinting:** Device parameters are logged to prevent multi-account creation on a single phone.

---

## 5. Identity Verification & Anti-Bot System
*   **Phase 1 - Zero-Cost Launcher Engine (MVP):** Users register via Supabase Phone Number OTP. Users upload a Government ID, which the Flutter client compresses to <150 KB. Images are stored in a restricted Supabase bucket. A Flutter Web Admin Console displays uploads for manual moderation. Once approved, the image is permanently deleted to save free-tier space.
*   **Phase 2 - Automated Scaling Engine (Post-MVP):** Integrates DigiLocker / Govt e-ID API for instant mobile verification. Document upload remains exclusively for web users without mobile OTP access.
  > ✅ SHIPPED in V4.0 (2026-08-23): DigiLocker flow + web-only manual fallback implemented; live credentials pending govt sandbox approval (simulator runs meanwhile). See `docs/V4_SPEC.md`.

---

## 6. Safety, Moderation & Compliance
*   **App Store Compliance:** Includes a mandatory custom End-User License Agreement (EULA) defining zero tolerance for illegal acts, an in-app "Report" option for legal categories, and a 2-way block mechanism.
*   **24-Hour Moderation SLA:** Posts accumulating threshold reports are automatically hidden (`is_hidden = true`) by an Edge Function while queued for review.
*   **Free-Tier AI Moderation:** Post text is passed through free-tier open-source moderation models (Hugging Face / Groq) to flag illegal content prior to database insertion.

---

## 7. Financial Model & Cost Controls
*   **Launch Tier Target ($0/mo):** Utilizes standard App Store/Play Store dev accounts, Supabase Free Tier (500 MB DB / 50k MAUs / 1 GB Storage), Vercel/Netlify (100 GB Bandwidth/mo), and Groq/Hugging Face free limits (14,400 Requests/day).
*   **Monetization ($10–$50 / month B2B Tier):** Subscriptions for political parties and NGOs unlock a Gold Verification Badge, Priority Push Broadcasts, a Right-of-Reply Fact-Check Portal, and Campaign Analytics. Phase 2 introduces Livestreaming once revenue covers video bandwidth.

---

## 8. Go-To-Market (GTM) Strategy
*   **Hyper-Local Expansion:** Target gated residential communities (via RWAs), university campus political clubs, and local municipal grassroots campaigns.
*   **Viral Mechanics:** Fact-checked posts produce shareable dynamic preview cards for WhatsApp, X (Twitter), and Telegram.

