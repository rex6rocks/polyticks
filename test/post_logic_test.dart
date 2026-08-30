// ─────────────────────────────────────────────
//  Polyticks – Post Logic Unit Tests
// ─────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/models/models.dart';

void main() {
  group('Post Interaction Logic', () {
    final jantaUser = AppUser(
      id: 'j1',
      displayName: 'Janta User',
      role: UserRole.janta,
      avatarColor: '#000000',
      email: 'janta@test.com'
    );
    
    final partyUser = AppUser(
      id: 'p1',
      displayName: 'Party User',
      role: UserRole.party,
      partyId: 'party1',
      avatarColor: '#000000',
      email: 'party@test.com'
    );
    
    final memberUserParty1 = AppUser(
      id: 'm1',
      displayName: 'Member Party 1',
      role: UserRole.partyMember,
      partyId: 'party1',
      avatarColor: '#000000',
      email: 'm1@test.com'
    );
    
    final memberUserParty2 = AppUser(
      id: 'm2',
      displayName: 'Member Party 2',
      role: UserRole.partyMember,
      partyId: 'party2',
      avatarColor: '#000000',
      email: 'm2@test.com'
    );

    final standardPostParty1 = Post(
      id: 'post1',
      partyId: 'party1',
      content: 'Hello',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      type: PostType.standard,
    );

    final memberTaggedPostParty1 = Post(
      id: 'post2',
      partyId: 'party1',
      content: 'Members only',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      type: PostType.memberTagged,
    );

    // Helper logic mirroring PostCard._canLike and _canComment
    bool canInteract(AppUser u, Post p) {
      if (u.role == UserRole.janta) return true;
      if (u.role == UserRole.party) return false;
      if (u.role == UserRole.partyMember) {
        return p.type == PostType.memberTagged && u.partyId == p.partyId;
      }
      return false;
    }

    test('Janta can interact with all posts', () {
      expect(canInteract(jantaUser, standardPostParty1), true);
      expect(canInteract(jantaUser, memberTaggedPostParty1), true);
    });

    test('Party cannot interact with any posts', () {
      expect(canInteract(partyUser, standardPostParty1), false);
      expect(canInteract(partyUser, memberTaggedPostParty1), false);
    });

    test('PartyMember can only interact with memberTagged posts of their own party', () {
      expect(canInteract(memberUserParty1, standardPostParty1), false);
      expect(canInteract(memberUserParty1, memberTaggedPostParty1), true);
      
      expect(canInteract(memberUserParty2, standardPostParty1), false);
      expect(canInteract(memberUserParty2, memberTaggedPostParty1), false);
    });
  });
}
