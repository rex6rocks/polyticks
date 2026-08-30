-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Migration 09 : V4.0 B2B Analytics Rollups
--  Target DB : Supabase (PostgreSQL 15+)   |   Tier target : FREE (Pro-ready)
--
--  Durable rollup layer for the B2B analytics dashboard. Aggregates the
--  core tables (posts / reactions / fact_checks) into org-scoped views so:
--    * raw `analytics_events` rows can be purged aggressively (migration 08)
--      without losing dashboard history;
--    * no event-ingestion pipeline is required to ship Phase 4.
--
--  SECURITY: both views use security_invoker (= ON) so underlying table RLS
--  applies, plus an explicit scoping predicate (own org or privileged).
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ─── SECTION 1 : PER-ORG POST ENGAGEMENT STATS ─────────────────────────────

CREATE OR REPLACE VIEW public.org_post_stats
WITH (security_invoker = true) AS
SELECT
    p.author_id                    AS org_id,
    COUNT(*)                       AS total_posts,
    COALESCE(SUM(p.like_count), 0)     AS total_likes,
    COALESCE(SUM(p.dislike_count), 0)  AS total_dislikes,
    CASE WHEN COALESCE(SUM(p.like_count) + SUM(p.dislike_count), 0) = 0
         THEN 0.0
         ELSE ROUND(SUM(p.dislike_count)::numeric
              / (SUM(p.like_count) + SUM(p.dislike_count)) * 100, 1)
    END                            AS dislike_ratio_pct,
    COUNT(*) FILTER (WHERE p.is_hidden)          AS hidden_posts,
    COUNT(*) FILTER (WHERE p.created_at > now() - interval '30 days')
                                   AS posts_last_30d
FROM public.posts p
WHERE p.author_id = auth.uid()
   OR public.caller_is_privileged()
GROUP BY p.author_id;


-- ─── SECTION 2 : FACT-CHECK OUTCOMES ON ORG CONTENT ─────────────────────────
--  Accountability view: what the crowd-sourced engine concluded about each
--  org's posts (Right-of-Reply / campaign-analytics input).

CREATE OR REPLACE VIEW public.org_fact_check_outcomes
WITH (security_invoker = true) AS
SELECT
    p.author_id AS org_id,
    COUNT(*) FILTER (WHERE p.fact_check_status = 'none')              AS clean_posts,
    COUNT(*) FILTER (WHERE p.fact_check_status = 'under_review')      AS under_review,
    COUNT(*) FILTER (WHERE p.fact_check_status = 'verified_context')  AS context_accepted,
    COUNT(*) FILTER (WHERE p.fact_check_status = 'disputed')          AS disputed,
    COUNT(*) FILTER (WHERE p.fact_check_status = 'auto_hidden')       AS auto_hidden,
    COALESCE(fc.notes_received, 0)                                    AS community_notes_received
FROM public.posts p
LEFT JOIN (
    SELECT post_id, COUNT(*) AS notes_received
    FROM public.fact_checks
    GROUP BY post_id
) fc ON fc.post_id = p.id
WHERE p.author_id = auth.uid()
   OR public.caller_is_privileged()
GROUP BY p.author_id, fc.notes_received;


-- ─── SECTION 3 : COMBINED DASHBOARD SUMMARY ─────────────────────────────────
--  One row per org joining engagement + outcomes. Feeds the B2B dashboard
--  screen directly (single query, RLS-scoped).

CREATE OR REPLACE VIEW public.org_analytics_summary
WITH (security_invoker = true) AS
SELECT
    COALESCE(ps.org_id, fco.org_id)                              AS org_id,
    COALESCE(ps.total_posts, 0)                                  AS total_posts,
    COALESCE(ps.total_likes, 0)                                  AS total_likes,
    COALESCE(ps.total_dislikes, 0)                               AS total_dislikes,
    COALESCE(ps.dislike_ratio_pct, 0)                            AS dislike_ratio_pct,
    COALESCE(ps.posts_last_30d, 0)                               AS posts_last_30d,
    COALESCE(fco.clean_posts, 0)                                 AS clean_posts,
    COALESCE(fco.under_review, 0)                                AS under_review,
    COALESCE(fco.context_accepted, 0)                            AS context_accepted,
    COALESCE(fco.disputed, 0)                                    AS disputed,
    COALESCE(fco.auto_hidden, 0)                                 AS auto_hidden,
    COALESCE(fco.community_notes_received, 0)                    AS community_notes_received
FROM public.org_post_stats ps
FULL OUTER JOIN public.org_fact_check_outcomes fco
    ON fco.org_id = ps.org_id;

COMMIT;
