// ─────────────────────────────────────────────
//  Polyticks V4.0 – Analytics Service Tests
// ─────────────────────────────────────────────
//
//  Covers the SIMULATION-mode contract of AnalyticsService (mirrors the
//  org_analytics_summary view shape from migration 09):
//    * empty store → null summary
//    * seeded fixture → full row mapping (num coercion, defaults)
//    * trust score math: clean/context share of judged posts
//    * trust score defaults to 100 when nothing judged
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/config.dart';
import 'package:polyticks/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Force simulation mode (no real credentials, no network).
    AppConfig.forceTestMode = true;
  });

  setUp(() {
    AnalyticsService.resetSimulation();
  });

  test('fetchSummary returns null when no data exists', () async {
    expect(await AnalyticsService.fetchSummary('org-x'), isNull);
  });

  test('seeded fixture maps every column of org_analytics_summary', () async {
    AnalyticsService.seedSimulation('org-1', {
      'org_id': 'org-1',
      'total_posts': 42,
      'total_likes': 900,
      'total_dislikes': 100,
      'dislike_ratio_pct': 10.0,
      'posts_last_30d': 12,
      'clean_posts': 30,
      'under_review': 5,
      'context_accepted': 7,
      'disputed': 0,
      'auto_hidden': 0,
      'community_notes_received': 15,
    });

    final s = await AnalyticsService.fetchSummary('org-1');
    expect(s, isNotNull);
    expect(s!.totalPosts, 42);
    expect(s.totalLikes, 900);
    expect(s.totalDislikes, 100);
    expect(s.dislikeRatioPct, 10.0);
    expect(s.postsLast30d, 12);
    expect(s.cleanPosts, 30);
    expect(s.underReview, 5);
    expect(s.contextAccepted, 7);
    expect(s.disputed, 0);
    expect(s.autoHidden, 0);
    expect(s.communityNotesReceived, 15);
  });

  test('trust score = clean+context share of judged posts', () async {
    AnalyticsService.seedSimulation('org-1', {
      'clean_posts': 30,
      'context_accepted': 10,
      'under_review': 5,
      'disputed': 5,
    });
    final s = await AnalyticsService.fetchSummary('org-1');
    // judged = 50; positive = 40 → 80%
    expect(s!.trustScorePct, closeTo(80.0, 0.01));
  });

  test('trust score defaults to 100 when no posts were judged', () async {
    AnalyticsService.seedSimulation('org-2', {'clean_posts': 0});
    final s = await AnalyticsService.fetchSummary('org-2');
    expect(s!.trustScorePct, 100.0);
  });

  test('missing columns coerce to zero defaults', () async {
    AnalyticsService.seedSimulation('org-3', {'org_id': 'org-3'});
    final s = await AnalyticsService.fetchSummary('org-3');
    expect(s!.totalPosts, 0);
    expect(s.dislikeRatioPct, 0.0);
    expect(s.communityNotesReceived, 0);
  });
}
