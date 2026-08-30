// ─────────────────────────────────────────────
//  Polyticks – Mock Data Unit Tests
// ─────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/data/mock_data.dart';
import 'package:polyticks/models/models.dart';

void main() {
  group('Mock Data Helpers', () {
    test('partyById returns correct party', () {
      final p1 = partyById('p1');
      expect(p1, isNotNull);
      expect(p1!.name, 'Aam Aadmi Dal');

      final none = partyById('nonexistent');
      expect(none, isNull);
    });

    test('commentsForPost returns comments for specific post', () {
      final comments = commentsForPost('post1');
      expect(comments.isNotEmpty, true);
      expect(comments.every((c) => c.postId == 'post1'), true);

      final noComments = commentsForPost('nonexistent_post');
      expect(noComments.isEmpty, true);
    });

    test('userById returns correct user', () {
      final u1 = userById('u1');
      expect(u1, isNotNull);
      expect(u1!.displayName, 'Arjun Sharma');

      final none = userById('nonexistent');
      expect(none, isNull);
    });
  });

  group('Mock Data Integrity', () {
    test('mockAccounts have correct role assignments', () {
      final jantaUsers = mockAccounts.where((a) => (a['user'] as AppUser).role == UserRole.janta);
      final partyUsers = mockAccounts.where((a) => (a['user'] as AppUser).role == UserRole.party);
      final memberUsers = mockAccounts.where((a) => (a['user'] as AppUser).role == UserRole.partyMember);

      expect(jantaUsers.isNotEmpty, true);
      expect(partyUsers.isNotEmpty, true);
      expect(memberUsers.isNotEmpty, true);
      
      // Party users must have a partyId
      for (final acc in partyUsers) {
        expect((acc['user'] as AppUser).partyId, isNotNull);
      }
      
      // Party Member users must have a partyId
      for (final acc in memberUsers) {
        expect((acc['user'] as AppUser).partyId, isNotNull);
      }
    });
  });
}
