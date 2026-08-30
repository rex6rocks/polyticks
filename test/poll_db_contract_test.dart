//
// poll_db_contract_test.dart
//
// V3 Phase 3 — Integration tests: database contract (REAL Supabase).
// Covers T3.1–T3.4 of pending/V3_PHASE3_TESTING.md.
//
// Requires a live, seeded project (supabase/seed_v3_tests.sql) and env vars:
//   SUPABASE_TEST_URL                 e.g. https://sbdwwmbocyqlkztptskb.supabase.co
//   SUPABASE_TEST_PUBLISHABLE_KEY     publishable (anon) key
//
// Seeded users U1/U2/U3 must have password 'Polyticks#Test2026'.
//

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String u1Id = '11111111-1111-1111-1111-111111111111'; // unverified
const String u2Id = '22222222-2222-2222-2222-222222222222'; // verified, Community A
const String communityAPostPoll = 'dd000000-0000-0000-0000-000000000001';
const String option1 = 'ee000000-0000-0000-0000-000000000001';
const String option2 = 'ee000000-0000-0000-0000-000000000002';

Future<SupabaseClient> signedInClient(String email) async {
  final url = Platform.environment['SUPABASE_TEST_URL']!;
  final key = Platform.environment['SUPABASE_TEST_PUBLISHABLE_KEY']!;
  final client = SupabaseClient(url, key);
  await client.auth
      .signInWithPassword(email: email, password: 'Polyticks#Test2026');
  return client;
}

Future<int> optionVoteCount(SupabaseClient client, String optionId) async {
  final row = await client
      .from('poll_options')
      .select('vote_count')
      .eq('id', optionId)
      .single();
  return row['vote_count'] as int;
}

Future<void> deleteVote(SupabaseClient client, String pollId, String voterId) async {
  await client.from('poll_votes').delete().eq('poll_id', pollId).eq('voter_id', voterId);
}

void main() {
  // Skip (not fail) when credentials are absent, so the default `flutter test`
  // suite stays green without a live backend.
  final hasCreds = Platform.environment['SUPABASE_TEST_URL'] != null &&
      Platform.environment['SUPABASE_TEST_PUBLISHABLE_KEY'] != null;

  void t(String name, Future<void> Function() body) {
    test(name, hasCreds ? body : () async {
      // ignore: avoid_print
      print('SKIP: $name (SUPABASE_TEST_* env vars not set)');
    }, skip: hasCreds ? false : 'live Supabase credentials not set');
  }

  group('V3 Phase 3 — Poll database contract (live Supabase)', () {
    t('T3.1: U2 insert succeeds and trigger auto-increments; '
        'delete auto-decrements', () async {
      final client = await signedInClient('u2@test.polyticks.app');
      await deleteVote(client, communityAPostPoll, u2Id); // clean slate
      final before = await optionVoteCount(client, option1);

      await client.from('poll_votes').insert({
        'poll_id': communityAPostPoll,
        'option_id': option1,
        'voter_id': u2Id,
      });

      // Trigger handle_poll_vote_change should have incremented.
      expect(await optionVoteCount(client, option1), before + 1);
      expect(await optionVoteCount(client, option2), 0);

      // Deleting the vote should auto-decrement back.
      await deleteVote(client, communityAPostPoll, u2Id);
      expect(await optionVoteCount(client, option1), before);
    });

    t('T3.2: duplicate insert (same poll_id + voter_id) raises '
        'unique violation', () async {
      final client = await signedInClient('u2@test.polyticks.app');
      await deleteVote(client, communityAPostPoll, u2Id); // clean slate

      final vote = {
        'poll_id': communityAPostPoll,
        'option_id': option2,
        'voter_id': u2Id,
      };
      await client.from('poll_votes').insert(vote);

      try {
        await client.from('poll_votes').insert(vote);
        fail('Duplicate (poll_id, voter_id) insert must violate the UNIQUE constraint');
      } on PostgrestException catch (e) {
        expect(e.code, '23505');
      } finally {
        await deleteVote(client, communityAPostPoll, u2Id); // cleanup
      }
    });

    t('T3.3: unverified U1 insert raises RLS violation', () async {
      final client = await signedInClient('u1@test.polyticks.app');
      await deleteVote(client, communityAPostPoll, u1Id); // clean slate

      try {
        await client.from('poll_votes').insert({
          'poll_id': communityAPostPoll,
          'option_id': option1,
          'voter_id': u1Id,
        });
        fail('Unverified user must not be able to vote (RLS)');
      } on PostgrestException catch (e) {
        expect(e.code, '42501');
        expect(e.message, contains('row-level security'));
      } finally {
        await deleteVote(client, communityAPostPoll, u1Id);
      }
    });

    t('T3.4: anonymous role CAN SELECT all poll tables but CANNOT '
        'INSERT votes', () async {
      final url = Platform.environment['SUPABASE_TEST_URL']!;
      final key = Platform.environment['SUPABASE_TEST_PUBLISHABLE_KEY']!;
      final anon = SupabaseClient(url, key); // no session -> anon role

      // Read access: communities, wards, polls, options, votes.
      // (poll_votes may legitimately be empty — success = no RLS error.)
      for (final table in ['communities', 'wards', 'polls', 'poll_options', 'poll_votes']) {
        await anon.from(table).select().limit(5);
      }

      // Write access: anon INSERT into poll_votes must be denied by RLS.
      try {
        await anon.from('poll_votes').insert({
          'poll_id': communityAPostPoll,
          'option_id': option1,
          'voter_id': u1Id,
        });
        fail('Anonymous role must not be able to insert votes (RLS)');
      } on PostgrestException catch (e) {
        expect(e.code, anyOf('42501', '403'),
            reason: 'RLS denial expected for anon insert');
      }
    });
  });
}
