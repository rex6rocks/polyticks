// ─────────────────────────────────────────────
//  Polyticks – Model Unit Tests
// ─────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/models/models.dart';

void main() {
  // ── AppUser ──────────────────────────────────
  group('AppUser', () {
    final jantaUser = AppUser(
      id: 'j1',
      displayName: 'Arjun Sharma',
      role: UserRole.janta,
      avatarColor: '#4ECDC4',
      email: 'arjun@janta.in',
    );

    final partyUser = AppUser(
      id: 'p1',
      displayName: 'Aam Aadmi Dal',
      role: UserRole.party,
      partyId: 'party1',
      avatarColor: '#FF6B00',
      email: 'aad@party.in',
    );

    final memberUser = AppUser(
      id: 'm1',
      displayName: 'Sneha Patel',
      role: UserRole.partyMember,
      partyId: 'party1',
      avatarColor: '#FDCB6E',
      email: 'sneha@member.in',
    );

    group('visibleName()', () {
      test('Janta sees their own real name', () {
        expect(jantaUser.visibleName(UserRole.janta), 'Arjun Sharma');
      });

      test('Janta is shown as "Janta" to Party viewers', () {
        expect(jantaUser.visibleName(UserRole.party), 'Janta');
      });

      test('Janta is shown as "Janta" to PartyMember viewers', () {
        expect(jantaUser.visibleName(UserRole.partyMember), 'Janta');
      });

      test('Party user sees their own real name when viewed by Janta', () {
        expect(partyUser.visibleName(UserRole.janta), 'Aam Aadmi Dal');
      });

      test('PartyMember user sees their own real name when viewed by another member', () {
        expect(memberUser.visibleName(UserRole.partyMember), 'Sneha Patel');
      });

      test('PartyMember user sees their own real name when viewed by Janta', () {
        expect(memberUser.visibleName(UserRole.janta), 'Sneha Patel');
      });
    });

    group('roleLabel', () {
      test('Janta role label is "Janta"', () {
        expect(jantaUser.roleLabel, 'Janta');
      });

      test('Party role label is "Party"', () {
        expect(partyUser.roleLabel, 'Party');
      });

      test('PartyMember role label is "Party Member"', () {
        expect(memberUser.roleLabel, 'Party Member');
      });
    });

    group('partyId', () {
      test('Janta user has null partyId', () {
        expect(jantaUser.partyId, isNull);
      });

      test('Party user has a partyId', () {
        expect(partyUser.partyId, isNotNull);
      });

      test('PartyMember user has a partyId', () {
        expect(memberUser.partyId, isNotNull);
      });
    });
  });

  // ── Poll ──────────────────────────────────────
  group('Poll', () {
    late Poll poll;

    setUp(() {
      poll = Poll(
        id: 'poll_test',
        partyId: 'p1',
        question: 'Which issue matters most?',
        options: [
          PollOption(id: 'o1', text: 'Healthcare', votes: 100),
          PollOption(id: 'o2', text: 'Education', votes: 200),
          PollOption(id: 'o3', text: 'Employment', votes: 150),
        ],
        endsAt: DateTime.now().add(const Duration(days: 3)),
      );
    });

    test('totalVotes sums all option votes correctly', () {
      expect(poll.totalVotes, 450);
    });

    test('totalVotes is 0 when all options have 0 votes', () {
      final emptyPoll = Poll(
        id: 'empty_poll',
        partyId: 'p1',
        question: 'Empty poll?',
        options: [
          PollOption(id: 'o1', text: 'Yes', votes: 0),
          PollOption(id: 'o2', text: 'No', votes: 0),
        ],
        endsAt: DateTime.now().add(const Duration(days: 1)),
      );
      expect(emptyPoll.totalVotes, 0);
    });

    test('votedOptionId starts as null', () {
      expect(poll.votedOptionId, isNull);
    });

    test('votedOptionId can be set', () {
      poll.votedOptionId = 'o1';
      expect(poll.votedOptionId, 'o1');
    });

    test('voting updates option vote count', () {
      final option = poll.options.firstWhere((o) => o.id == 'o2');
      option.votes++;
      expect(poll.totalVotes, 451);
    });
  });

  // ── PollOption ────────────────────────────────
  group('PollOption', () {
    test('votes can be incremented', () {
      final opt = PollOption(id: 'x', text: 'Test', votes: 5);
      opt.votes++;
      expect(opt.votes, 6);
    });
  });

  // ── PostType enum ─────────────────────────────
  group('PostType', () {
    test('standard is a valid PostType', () {
      const t = PostType.standard;
      expect(t, PostType.standard);
    });

    test('memberTagged is a valid PostType', () {
      const t = PostType.memberTagged;
      expect(t, PostType.memberTagged);
    });
  });

  // ── UserRole enum ─────────────────────────────
  group('UserRole', () {
    test('all three roles exist', () {
      expect(UserRole.values.length, 3);
      expect(UserRole.values, contains(UserRole.janta));
      expect(UserRole.values, contains(UserRole.party));
      expect(UserRole.values, contains(UserRole.partyMember));
    });
  });
}
