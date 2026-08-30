// ─────────────────────────────────────────────
//  Polyticks – Optimistic Poll Voting Unit Tests (Phase 2 / V3 Task 3.3)
//
//  Covers:
//   T2.1 Happy path: local voteCount increments IMMEDIATELY (before the
//        async insert resolves); votedOptionId set -> UI Results Mode.
//   T2.2 Double vote: UNIQUE(poll_id, voter_id) mirrored in sim mode ->
//        error caught, ALL counts reverted, exact failure message surfaced.
//   T2.3 Unverified voter: RLS denial mirrored -> revert + message.
//   T2.4 Wrong community: verified Community-B member votes on a
//        Community-A poll -> RLS denial mirrored -> revert + message.
//   T2.5 Percentage math + zero-total-votes divide-by-zero guard.
//
//  Strategy: `SupabaseService.voteInPoll` performs the optimistic update,
//  then persists to `poll_votes` (real Supabase) or validates against the
//  mirrored DB contract in simulation (UNIQUE constraint + "Verified
//  community members can vote" RLS policy). The literal real-path wiring is
//  additionally guarded by source-contract assertions; live-DB proof comes
//  in Phase 3.
// ─────────────────────────────────────────────
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/models/models.dart';
import 'package:polyticks/providers/poll_provider.dart';
import 'package:polyticks/services/supabase_service.dart';

// Phase-0 seeded IDs (supabase/seed_v3_tests.sql)
const String u1 = '11111111-1111-1111-1111-111111111111'; // unverified
const String u2 = '22222222-2222-2222-2222-222222222222'; // verified, Comm A
const String u3 = '33333333-3333-3333-3333-333333333333'; // verified, Comm B
const String commA = 'a0000000-0000-0000-0000-000000000001';
const String commB = 'b0000000-0000-0000-0000-000000000002';
const String pollId = 'dd000000-0000-0000-0000-000000000001';
const String opt1 = 'ee000000-0000-0000-0000-000000000001';
const String opt2 = 'ee000000-0000-0000-0000-000000000002';
const String opt3 = 'ee000000-0000-0000-0000-000000000003';

Poll freshPoll() {
  return Poll(
    id: pollId,
    partyId: 'p1',
    question: 'Should the ward get a new park?',
    options: [
      PollOption(id: opt1, text: 'Yes', votes: 5),
      PollOption(id: opt2, text: 'No', votes: 3),
      PollOption(id: opt3, text: 'Maybe', votes: 0),
    ],
    endsAt: DateTime.utc(2026, 12, 31),
  );
}

List<AppUser> voters() => [
      AppUser(
        id: u1,
        displayName: 'U1',
        role: UserRole.janta,
        avatarColor: '#FFF',
        email: 'u1@test.in',
        communityId: null,
        isVerified: false,
      ),
      AppUser(
        id: u2,
        displayName: 'U2',
        role: UserRole.partyMember,
        avatarColor: '#FFF',
        email: 'u2@test.in',
        communityId: commA,
        isVerified: true,
      ),
      AppUser(
        id: u3,
        displayName: 'U3',
        role: UserRole.partyMember,
        avatarColor: '#FFF',
        email: 'u3@test.in',
        communityId: commB,
        isVerified: true,
      ),
    ];

/// Seeds the service with one Community-A poll (mirrors the Phase-0 seed:
/// poll dd...0001 with options ee...0001/0002/0003 on Community-A post
/// aa...0001). Returns the stored poll object — `voteInPoll` mutates it in
/// place, so assertions read through this reference.
Poll seedService() {
  final poll = freshPoll();
  SupabaseService.instance.debugSeedSimulatedPolls(
    [(poll: poll, communityId: commA)],
    users: voters(),
  );
  return poll;
}

void main() {
  group('T2.1 — Happy path: optimistic increment BEFORE async resolves', () {
    test('service increments voteCount synchronously, persists after await',
        () async {
      final poll = seedService();
      final service = SupabaseService.instance;

      final future = service.voteInPoll(u2, pollId, opt1);

      // IMMEDIATE check: runs before any await inside voteInPoll resolved —
      // the optimistic mutation is already visible on the seeded object.
      expect(future, isA<Future<bool>>());
      expect(poll.options.firstWhere((o) => o.id == opt1).votes, 6);
      expect(poll.votedOptionId, opt1); // Results Mode flag set

      expect(await future, isTrue);
      expect(service.lastPollVoteError, isNull);
      expect(poll.options.firstWhere((o) => o.id == opt1).votes, 6);
    });

    test('Riverpod provider state switches to Results Mode immediately',
        () async {
      seedService();
      final notifier =
          PollNotifier(freshPoll(), SupabaseService.instance, userId: u2);
      final future = notifier.vote(opt1);

      // IMMEDIATE: before the async insert resolves, provider state already
      // shows the incremented count AND votedOptionId (Results Mode).
      expect(notifier.state.votedOptionId, opt1);
      expect(
        notifier.state.options.firstWhere((o) => o.id == opt1).votes,
        6,
      );
      expect(notifier.state.totalVotes, 9); // 5+3+0 + 1

      expect(await future, isTrue);
      expect(notifier.state.votedOptionId, opt1);
    });
  });

  group('T2.2 — Double vote hits UNIQUE(poll_id, voter_id)', () {
    test('second vote reverts ALL counts and surfaces exact SnackBar message',
        () async {
      final poll = seedService();
      final service = SupabaseService.instance;

      expect(await service.voteInPoll(u2, pollId, opt1), isTrue);
      expect(poll.options.firstWhere((o) => o.id == opt1).votes, 6);

      // Second vote by same user on a different option -> UNIQUE violation.
      expect(await service.voteInPoll(u2, pollId, opt2), isFalse);

      // ALL counts reverted to pre-second-vote values.
      expect(poll.options.map((o) => o.votes).toList(), [6, 3, 0]);
      expect(poll.votedOptionId, opt1); // first vote preserved
      expect(service.lastPollVoteError,
          'Action failed: Ensure you are a verified community member');
    });

    test('provider reverts to full pre-vote state on failure', () async {
      seedService();
      final notifier =
          PollNotifier(freshPoll(), SupabaseService.instance, userId: u2);

      expect(await notifier.vote(opt1), isTrue);
      final afterFirst = notifier.state;

      expect(await notifier.vote(opt2), isFalse);
      expect(identical(notifier.state, afterFirst), isTrue);
      expect(notifier.state.options.map((o) => o.votes).toList(), [6, 3, 0]);
      expect(
        notifier.state.options.map((o) => o.text).toList(),
        ['Yes', 'No', 'Maybe'],
      );
    });
  });

  group('T2.3 — Unverified voter denied (RLS mirror)', () {
    test('U1 insert denied, counts revert, SnackBar message recorded',
        () async {
      final poll = seedService();
      final service = SupabaseService.instance;

      expect(await service.voteInPoll(u1, pollId, opt1), isFalse);
      expect(poll.options.map((o) => o.votes).toList(), [5, 3, 0]);
      expect(poll.votedOptionId, isNull);
      expect(service.lastPollVoteError,
          'Action failed: Ensure you are a verified community member');
    });
  });

  group('T2.4 — Wrong community denied (RLS mirror)', () {
    test('Community-B member cannot vote on Community-A local poll', () async {
      final poll = seedService();
      final service = SupabaseService.instance;

      expect(await service.voteInPoll(u3, pollId, opt1), isFalse);
      expect(poll.options.map((o) => o.votes).toList(), [5, 3, 0]);
      expect(poll.votedOptionId, isNull);
      expect(service.lastPollVoteError,
          'Action failed: Ensure you are a verified community member');

      // Control: U2 (same community) still succeeds afterwards.
      expect(await service.voteInPoll(u2, pollId, opt1), isTrue);
      expect(poll.options.firstWhere((o) => o.id == opt1).votes, 6);
    });
  });

  group('T2.5 — Percentage math + zero-total guard', () {
    test('(voteCount / totalVotes) * 100 computed correctly', () {
      expect(SupabaseService.pollOptionPercent(voteCount: 3, totalVotes: 12),
          25.0);
      expect(SupabaseService.pollOptionPercent(voteCount: 5, totalVotes: 8),
          62.5);
      expect(SupabaseService.pollOptionPercent(voteCount: 1, totalVotes: 3),
          closeTo(33.333, 0.01));
    });

    test('zero total votes returns 0% and never divides by zero', () {
      final pct =
          SupabaseService.pollOptionPercent(voteCount: 4, totalVotes: 0);
      expect(pct, 0.0);
      expect(pct.isFinite, isTrue); // no NaN / Infinity leak into UI
      expect(pct.isNaN, isFalse);

      final negativeTotal =
          SupabaseService.pollOptionPercent(voteCount: 4, totalVotes: -3);
      expect(negativeTotal, 0.0);
      expect(negativeTotal.isFinite, isTrue);
    });
  });

  group('Wiring guard — real-query branch writes the DB contract', () {
    final source =
        File('lib/services/supabase_service.dart').readAsStringSync();
    final from = source.indexOf('Future<bool> voteInPoll');
    final body =
        source.substring(from, source.indexOf('bool _revertPollVote', from));

    test('voteInPoll real path inserts into poll_votes with voter_id', () {
      expect(body, contains("from('poll_votes').insert("));
      expect(body, contains("'voter_id': userId"));
    });

    test('optimistic update happens BEFORE the await (source contract)', () {
      final optimisticAt = body.indexOf('option.votes += 1;');
      final awaitAt = body.indexOf('await _client!');
      expect(optimisticAt, greaterThan(-1));
      expect(awaitAt, greaterThan(optimisticAt));
    });

    test('failure path performs a FULL revert of all option counts', () {
      final revertSource =
          source.substring(source.indexOf('bool _revertPollVote'));
      expect(revertSource, contains('preVotes[i]'));
      expect(revertSource, contains('pollVoteFailureMessage'));
    });
  });
}
