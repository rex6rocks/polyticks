// ─────────────────────────────────────────────
//  Polyticks – Dual-Feed Wiring Unit Tests (Phase 1 / V3 Task 3.3)
//
//  Covers:
//   T1.1 hyperLocal=true + valid communityId -> .eq('community_id', <id>)
//   T1.2 hyperLocal=false (Broader/National) -> community_id IS NULL
//   T1.3 Simulation fallback matches real-query semantics for BOTH modes
//   T1.4 Results ordered by created_at DESC after filtering
//
//  Strategy: the SQL filter mapping lives in SupabaseService.feedFilterSpec()
//  and the simulation fallback runs through the SAME spec via
//  applyFeedFilter(). This guarantees simulation can never drift from the
//  real query. The literal `.eq(...)` / `.isFilter(...)` wiring in the real
//  branch is additionally guarded by a source-contract assertion below;
//  live-DB proof comes in Phase 3.
// ─────────────────────────────────────────────
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/models/models.dart';
import 'package:polyticks/services/supabase_service.dart';

const String commA = 'a0000000-0000-0000-0000-000000000001';
const String commB = 'b0000000-0000-0000-0000-000000000002';

Post _post(
  String id, {
  DateTime? createdAt,
  String? communityId,
  ChannelType channelType = ChannelType.hyperLocal,
  bool isHidden = false,
}) {
  return Post(
    id: id,
    partyId: 'p1',
    content: 'content-$id',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    likeCount: 0,
    commentCount: 0,
    type: PostType.standard,
    channelType: channelType,
    communityId: communityId,
    isHidden: isHidden,
  );
}

/// Fixture mirroring the Phase-0 seed: 2 Community-A posts, 1 Community-B
/// post, 2 national posts (`community_id IS NULL`), plus one hidden A post.
List<Post> fixture() => [
      _post('a-1',
          communityId: commA, createdAt: DateTime.utc(2026, 1, 1)),
      _post('a-2',
          communityId: commA, createdAt: DateTime.utc(2026, 1, 3)),
      _post('b-1',
          communityId: commB, createdAt: DateTime.utc(2026, 1, 4)),
      _post('n-1',
          communityId: null,
          channelType: ChannelType.broader,
          createdAt: DateTime.utc(2026, 1, 5)),
      _post('n-2',
          communityId: null,
          channelType: ChannelType.broader,
          createdAt: DateTime.utc(2026, 1, 2)),
      _post('hidden-a',
          communityId: commA,
          isHidden: true,
          createdAt: DateTime.utc(2026, 1, 6)),
    ];

void main() {
  group('T1.1 + T1.2 — SQL filter mapping (feedFilterSpec)', () {
    // T1.1
    test('hyperLocal=true with valid communityId maps to .eq(community_id)',
        () {
      final spec =
          SupabaseService.feedFilterSpec(hyperLocal: true, communityId: commA);
      expect(spec.eqCommunityId, commA);
      expect(spec.communityIdIsNull, isFalse);
    });

    test('hyperLocal=true without communityId falls back to national filter',
        () {
      final spec = SupabaseService.feedFilterSpec(hyperLocal: true);
      expect(spec.eqCommunityId, isNull);
      expect(spec.communityIdIsNull, isTrue);
    });

    // T1.2
    test(
        'hyperLocal=false (Broader/National) maps to community_id IS NULL',
        () {
      final spec = SupabaseService.feedFilterSpec(hyperLocal: false);
      expect(spec.eqCommunityId, isNull);
      expect(spec.communityIdIsNull, isTrue);
    });
  });

  group('Wiring guard — real-query branch uses the mapped filters', () {
    final source =
        File('lib/services/supabase_service.dart').readAsStringSync();
    final from = source.indexOf('Future<List<Post>> getPosts');
    final getPostsBody = source.substring(from, source.indexOf('Future<Post?', from));

    // T1.1 literal wiring
    test('getPosts real path contains .eq(community_id) for hyper-local',
        () {
      expect(getPostsBody, contains("query.eq('community_id'"));
    });

    // T1.2 literal wiring
    test(
        'getPosts real path contains .isFilter(community_id, null) for national',
        () {
      expect(getPostsBody, contains(".isFilter('community_id', null)"));
    });

    // T1.4 literal wiring
    test('getPosts real path orders by created_at descending', () {
      expect(getPostsBody, contains(".order('created_at', ascending: false)"));
    });
  });

  group('T1.3 — Simulation fallback matches real-query semantics', () {
    late SupabaseService service;

    setUp(() {
      service = SupabaseService.instance;
      service.debugSeedSimulatedPosts(fixture());
    });

    test('hyperLocal=true returns ONLY posts of that exact community',
        () async {
      final posts =
          await service.getPosts(hyperLocal: true, communityId: commA);
      // Real query returns only Community-A non-hidden posts — no B posts,
      // no national posts, regardless of channelType/type values.
      expect(posts.map((p) => p.id).toSet(), {'a-1', 'a-2'});
    });

    test('hyperLocal=true for another community returns only its posts',
        () async {
      final posts =
          await service.getPosts(hyperLocal: true, communityId: commB);
      expect(posts.map((p) => p.id), ['b-1']);
    });

    test(
        'hyperLocal=false (national) returns ONLY community_id IS NULL posts',
        () async {
      final posts = await service.getPosts(); // defaults hyperLocal: false
      expect(posts.map((p) => p.id).toSet(), {'n-1', 'n-2'});
    });

    test('hidden posts excluded in BOTH modes (is_hidden=false parity)',
        () async {
      final local =
          await service.getPosts(hyperLocal: true, communityId: commA);
      final national = await service.getPosts(hyperLocal: false);
      expect(local.map((p) => p.id), isNot(contains('hidden-a')));
      expect(national.map((p) => p.id),
          everyElement(isNot(equals('hidden-a'))));
    });
  });

  group('T1.4 — created_at DESC ordering after filtering', () {
    test('applyFeedFilter sorts newest first', () {
      final result =
          SupabaseService.applyFeedFilter(fixture(), hyperLocal: false);
      expect(result.map((p) => p.id).toList(), ['n-1', 'n-2']);
    });

    test('simulation getPosts sorts newest first within each mode', () async {
      final service = SupabaseService.instance;
      service.debugSeedSimulatedPosts(fixture());

      final local =
          await service.getPosts(hyperLocal: true, communityId: commA);
      final localDates = local.map((p) => p.createdAt).toList();
      expect(localDates,
          orderedEquals(localDates.toList()..sort((a, b) => b.compareTo(a))));
      expect(local.first.id, 'a-2'); // Jan 3 newer than a-1 Jan 1

      final national = await service.getPosts(hyperLocal: false);
      expect(national.first.id, 'n-1'); // Jan 5 newer than n-2 Jan 2
    });
  });
}
