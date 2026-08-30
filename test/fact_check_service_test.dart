import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/config.dart';
import 'package:polyticks/core/exceptions.dart';
import 'package:polyticks/services/fact_check_service.dart';

void main() {
  group('FactCheckService Simulation Tests', () {
    late FactCheckService service;

    setUp(() {
      // Force simulation mode
      AppConfig.forceTestMode = true;
      service = FactCheckService.instance;
      service.clearSimulatedData();
      FactCheckService.simulatedUserId = 'm1'; // Sneha Patel, verified party member
    });

    test('fetchNotesForPost returns seeded fact checks with author profile and votes list', () async {
      final notes = await service.fetchNotesForPost('post1');

      expect(notes, isNotEmpty);
      final firstNote = notes.first;
      expect(firstNote['post_id'], 'post1');
      expect(firstNote['profiles'], isNotNull);
      expect(firstNote['profiles']['username'], 'sneha_patel');
      expect(firstNote['fact_check_votes'], isA<List>());
    });

    test('submitFactCheck allows verified party member to post a note', () async {
      FactCheckService.simulatedUserId = 'm1'; // Sneha Patel (verified)
      final initialNotes = await service.fetchNotesForPost('post1');
      final initialCount = initialNotes.length;

      await service.submitFactCheck(
        postId: 'post1',
        contextNote: 'This is a test verified community note.',
        sourceLinks: ['https://example.com/source'],
      );

      final updatedNotes = await service.fetchNotesForPost('post1');
      expect(updatedNotes.length, initialCount + 1);
      expect(updatedNotes.first['context_note'], 'This is a test verified community note.');
      expect(updatedNotes.first['profiles']['username'], 'Sneha Patel');
    });

    test('submitFactCheck blocks unverified user and throws VerificationRequiredException', () async {
      FactCheckService.simulatedUserId = 'u3'; // Ravi Kumar (unverified)

      expect(
        () => service.submitFactCheck(
          postId: 'post1',
          contextNote: 'Unverified note.',
          sourceLinks: [],
        ),
        throwsA(isA<VerificationRequiredException>()),
      );
    });

    test('submitFactCheck enforces 5 submissions per 24 hours rate limit', () async {
      FactCheckService.simulatedUserId = 'm1'; // Sneha Patel (verified) - has 1 pre-seeded note

      // Submit 4 more notes (bringing total to 5 notes in 24 hours)
      for (int i = 0; i < 4; i++) {
        await service.submitFactCheck(
          postId: 'post1',
          contextNote: 'Note number $i',
          sourceLinks: [],
        );
      }

      // The 6th note submission should trigger RateLimitExceededException
      expect(
        () => service.submitFactCheck(
          postId: 'post1',
          contextNote: '6th Note',
          sourceLinks: [],
        ),
        throwsA(isA<RateLimitExceededException>()),
      );
    });

    test('voteOnNote allows casting an upvote and increments upvote counter', () async {
      FactCheckService.simulatedUserId = 'm1'; // Sneha Patel (verified, hasn't voted on fc1 yet)

      final notesBefore = await service.fetchNotesForPost('post1');
      final note1Before = notesBefore.firstWhere((n) => n['id'] == 'fc1');
      final initialUpvotes = note1Before['upvotes'] as int;

      await service.voteOnNote(noteId: 'fc1', voteType: 'upvote');

      final notesAfter = await service.fetchNotesForPost('post1');
      final note1After = notesAfter.firstWhere((n) => n['id'] == 'fc1');
      expect(note1After['upvotes'], initialUpvotes + 1);
    });

    test('voteOnNote blocks casting same vote twice and throws DuplicateVoteException', () async {
      FactCheckService.simulatedUserId = 'm2'; // Vikram Singh (verified) - already has a seeded upvote on fc1

      // Casting the same vote again should fail immediately
      expect(
        () => service.voteOnNote(noteId: 'fc1', voteType: 'upvote'),
        throwsA(isA<DuplicateVoteException>()),
      );
    });

    test('voteOnNote allows vote flipping (upvote to downvote)', () async {
      // Seed initial state has m2 voting upvote on fc1
      // Set current user as m2
      FactCheckService.simulatedUserId = 'm2'; 

      final notesBefore = await service.fetchNotesForPost('post1');
      final note1Before = notesBefore.firstWhere((n) => n['id'] == 'fc1');
      final initialUpvotes = note1Before['upvotes'] as int;
      final initialDownvotes = note1Before['downvotes'] as int;

      // Flip vote to downvote
      await service.voteOnNote(noteId: 'fc1', voteType: 'downvote');

      final notesAfter = await service.fetchNotesForPost('post1');
      final note1After = notesAfter.firstWhere((n) => n['id'] == 'fc1');

      expect(note1After['upvotes'], initialUpvotes - 1);
      expect(note1After['downvotes'], initialDownvotes + 1);
    });

    test('retractVote removes vote and decrements counters properly', () async {
      FactCheckService.simulatedUserId = 'm2'; // has seeded upvote on fc1

      final notesBefore = await service.fetchNotesForPost('post1');
      final note1Before = notesBefore.firstWhere((n) => n['id'] == 'fc1');
      final initialUpvotes = note1Before['upvotes'] as int;

      await service.retractVote(noteId: 'fc1');

      final notesAfter = await service.fetchNotesForPost('post1');
      final note1After = notesAfter.firstWhere((n) => n['id'] == 'fc1');

      expect(note1After['upvotes'], initialUpvotes - 1);
    });
  });
}
