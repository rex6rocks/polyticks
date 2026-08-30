// ─────────────────────────────────────────────
//  Polyticks V4.0 – B2B Analytics Service
// ─────────────────────────────────────────────
//
//  Reads the org-scoped rollup views (migration 09):
//    * org_post_stats            – engagement totals + dislike ratio
//    * org_fact_check_outcomes   – crowd verdicts on org content
//    * org_analytics_summary     – combined dashboard row (used here)
//
//  Access is RLS-enforced server-side (security_invoker views scope rows to
//  the caller's own org or privileged callers); the client simply selects.
//
//  SIMULATION MODE mirrors the view shape in-memory so tests and offline
//  dev runs exercise identical contracts (docs/V2_STATE_MANAGEMENT_SPEC.md).
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class OrgAnalyticsSummary {
  final String orgId;
  final int totalPosts;
  final int totalLikes;
  final int totalDislikes;
  final double dislikeRatioPct;
  final int postsLast30d;
  final int cleanPosts;
  final int underReview;
  final int contextAccepted;
  final int disputed;
  final int autoHidden;
  final int communityNotesReceived;

  const OrgAnalyticsSummary({
    required this.orgId,
    this.totalPosts = 0,
    this.totalLikes = 0,
    this.totalDislikes = 0,
    this.dislikeRatioPct = 0,
    this.postsLast30d = 0,
    this.cleanPosts = 0,
    this.underReview = 0,
    this.contextAccepted = 0,
    this.disputed = 0,
    this.autoHidden = 0,
    this.communityNotesReceived = 0,
  });

  factory OrgAnalyticsSummary.fromRow(Map<String, dynamic> row) {
    return OrgAnalyticsSummary(
      orgId: row['org_id'] as String? ?? '',
      totalPosts: (row['total_posts'] as num?)?.toInt() ?? 0,
      totalLikes: (row['total_likes'] as num?)?.toInt() ?? 0,
      totalDislikes: (row['total_dislikes'] as num?)?.toInt() ?? 0,
      dislikeRatioPct: (row['dislike_ratio_pct'] as num?)?.toDouble() ?? 0,
      postsLast30d: (row['posts_last_30d'] as num?)?.toInt() ?? 0,
      cleanPosts: (row['clean_posts'] as num?)?.toInt() ?? 0,
      underReview: (row['under_review'] as num?)?.toInt() ?? 0,
      contextAccepted: (row['context_accepted'] as num?)?.toInt() ?? 0,
      disputed: (row['disputed'] as num?)?.toInt() ?? 0,
      autoHidden: (row['auto_hidden'] as num?)?.toInt() ?? 0,
      communityNotesReceived:
          (row['community_notes_received'] as num?)?.toInt() ?? 0,
    );
  }

  /// Crowd trust score: share of engaged posts that ended clean or with
  /// accepted context. Simple, explainable, good enough for a dashboard card.
  double get trustScorePct {
    final judged = cleanPosts + contextAccepted + underReview + disputed;
    if (judged == 0) return 100.0;
    return ((cleanPosts + contextAccepted) / judged) * 100;
  }
}

class AnalyticsService {
  AnalyticsService._();

  // Simulation store (orgId → summary fixture).
  static final Map<String, Map<String, dynamic>> _simulated = {};

  static Future<OrgAnalyticsSummary?> fetchSummary(String orgId) async {
    final service = SupabaseService.instance;
    if (!service.isRealSupabase) {
      final row = _simulated[orgId];
      debugPrint('Analytics SIMULATION: ${row != null ? "hit" : "empty"} for $orgId');
      return row == null ? null : OrgAnalyticsSummary.fromRow(row);
    }
    // Live mode: fall back to the authenticated user for mock ids.
    if (!SupabaseService.isUuid(orgId)) orgId = service.currentUserId ?? '';
    if (!SupabaseService.isUuid(orgId)) return null;
    try {
      final rows = await service.client!
          .from('org_analytics_summary')
          .select()
          .eq('org_id', orgId)
          .limit(1);
      if (rows.isEmpty) return null;
      return OrgAnalyticsSummary.fromRow(rows.first);
    } catch (e) {
      debugPrint('fetchSummary failed: $e');
      return null;
    }
  }

  /// Test hook: seed a simulated summary fixture.
  @visibleForTesting
  static void seedSimulation(String orgId, Map<String, dynamic> row) =>
      _simulated[orgId] = row;

  /// Test hook: reset simulation state between tests.
  @visibleForTesting
  static void resetSimulation() => _simulated.clear();
}
