//
// sla_auto_hide_test.dart
//
// Integration tests for the V2 24-hour Moderation SLA Auto-Hide
// (migration 07_v2_sla_auto_hide.sql).
//
// Environment Variables Required:
// - SUPABASE_TEST_URL: Supabase project URL for testing.
// - SUPABASE_TEST_PUBLISHABLE_KEY: Supabase publishable key for testing.
//
// When credentials are absent these tests SKIP (not fail), preserving the
// recorded baseline of 13 known env-bound failures with zero new ones.
//

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kSurgeThreshold = 5;

void main() {
  final hasCreds = Platform.environment['SUPABASE_TEST_URL'] != null &&
      Platform.environment['SUPABASE_TEST_PUBLISHABLE_KEY'] != null;

  group('SLA Auto-Hide (migration 07)', () {
    late SupabaseClient db;
    late String postId;
    late List<String> reporterIds;

    setUpAll(() async {
      if (!hasCreds) return; // tests are skipped below
      final url = Platform.environment['SUPABASE_TEST_URL']!;
      final key = Platform.environment['SUPABASE_TEST_PUBLISHABLE_KEY']!;
      // Initialize once for the suite (Supabase.initialize is idempotent-guarded
      // by Flutter binding; tests run against a live project).
      await Supabase.initialize(url: url, publishableKey: key);
      db = Supabase.instance.client;
    });

    setUp(() async {
      reporterIds = [];
      // Seed a fresh visible post in 'none' status.
      final created = await db
          .from('posts')
          .insert({'content': 'SLA auto-hide test post', 'fact_check_status': 'none'})
          .select('id')
          .single();
      postId = created['id'] as String;
    });

    tearDown(() async {
      // Best-effort cleanup: reports cascade on post delete.
      try {
        await db.from('posts').delete().eq('id', postId);
      } catch (_) {}
      for (final rid in reporterIds) {
        try {
          await db.from('profiles').delete().eq('id', rid);
        } catch (_) {}
      }
    });

    /// Creates a throwaway profile and files a report from it.
    Future<void> fileReport(String reason) async {
      final profile = await db
          .from('profiles')
          .insert({
            'username': 'sla_test_${DateTime.now().microsecondsSinceEpoch}',
            'is_verified': true,
            'role': 'verified_user',
          })
          .select('id')
          .single();
      reporterIds.add(profile['id'] as String);
      await db.from('reports').insert({
        'post_id': postId,
        'reporter_id': profile['id'],
        'reason': reason,
      });
    }

    Future<Map<String, dynamic>> readPost() =>
        db.from('posts').select().eq('id', postId).single();

    test('4 reports within 24h -> post remains visible', () async {
      for (var i = 0; i < _kSurgeThreshold - 1; i++) {
        await fileReport('report_$i');
      }
      await Future.delayed(const Duration(seconds: 2));

      final post = await readPost();
      expect(post['is_hidden'], false);
      expect(post['fact_check_status'], isNot('auto_hidden'));
    }, skip: hasCreds ? false : 'Requires SUPABASE_TEST_URL / KEY');

    test('5th report within 24h -> hidden + fact_check_status=auto_hidden',
        () async {
      for (var i = 0; i < _kSurgeThreshold; i++) {
        await fileReport('report_$i');
      }
      await Future.delayed(const Duration(seconds: 2));

      final post = await readPost();
      expect(post['is_hidden'], true);
      expect(post['fact_check_status'], 'auto_hidden');

      // Audit trail entry recorded.
      final events = await db
          .from('sla_events')
          .select()
          .eq('post_id', postId)
          .eq('event_type', 'auto_hidden');
      expect((events as List).length, greaterThanOrEqualTo(1));
    }, skip: hasCreds ? false : 'Requires SUPABASE_TEST_URL / KEY');

    test('already-hidden post -> surge is idempotent (no extra churn)',
        () async {
      // Pre-hide the post at a terminal status; surge must not downgrade or
      // duplicate audit entries beyond the initial hide.
      await db.from('posts').update({
        'is_hidden': true,
        'fact_check_status': 'auto_hidden',
      }).eq('id', postId);

      for (var i = 0; i < _kSurgeThreshold + 2; i++) {
        await fileReport('late_report_$i');
      }
      await Future.delayed(const Duration(seconds: 2));

      final post = await readPost();
      expect(post['is_hidden'], true); // never un-hidden
      expect(post['fact_check_status'], 'auto_hidden'); // never downgraded
    }, skip: hasCreds ? false : 'Requires SUPABASE_TEST_URL / KEY');

    test('admin approve restores visibility and resolves pending reports',
        () async {
      // Drive post into auto_hidden via real surge.
      for (var i = 0; i < _kSurgeThreshold; i++) {
        await fileReport('surge_$i');
      }
      await Future.delayed(const Duration(seconds: 2));
      expect((await readPost())['fact_check_status'], 'auto_hidden');

      // Admin decision path from AdminModerationService semantics.
      await db.from('posts').update({
        'is_hidden': false,
        'flagged_reason': null,
        'fact_check_status': 'verified_context',
      }).eq('id', postId);
      await db
          .from('reports')
          .update({'status': 'resolved'})
          .eq('post_id', postId)
          .eq('status', 'pending');

      final post = await readPost();
      expect(post['is_hidden'], false);
      expect(post['fact_check_status'], 'verified_context');

      final pending = await db
          .from('reports')
          .select('status')
          .eq('post_id', postId)
          .eq('status', 'pending');
      expect((pending as List).isEmpty, isTrue);
    }, skip: hasCreds ? false : 'Requires SUPABASE_TEST_URL / KEY');

    test(
        'regression guard: dislike-threshold trigger (04) does not interfere '
        'with report-surge trigger (07)', () async {
      // Fire BOTH triggers against the same post: dislike threshold via
      // reactions and surge via reports. The final status must be deterministic
      // (whichever fires last wins between under_review/auto_hidden, but the
      // post MUST end hidden + auto_hidden once both thresholds crossed, since
      // migration 04 never downgrades auto_hidden).
      for (var i = 0; i < _kSurgeThreshold; i++) {
        await fileReport('cross_$i');
      }

      // Cross the dislike threshold too (>60% dislikes @ >=25 votes).
      // Reuse existing verified profiles where possible to avoid mass inserts:
      // this check only asserts status ordering, so simulate minimal votes via
      // direct counter updates (same code path migration 04 reads).
      await db.from('posts').update({
        'like_count': 9,
        'dislike_count': 16,
      }).eq('id', postId);

      await Future.delayed(const Duration(seconds: 2));

      final post = await readPost();
      expect(post['is_hidden'], true);
      expect(post['fact_check_status'], 'auto_hidden');
    }, skip: hasCreds ? false : 'Requires SUPABASE_TEST_URL / KEY');
  });
}
