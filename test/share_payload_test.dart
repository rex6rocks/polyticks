//
// share_payload_test.dart
//
// V3 Phase 5 — Client share integration tests (T5.1 of pending/V3_PHASE3_TESTING.md).
//
// Verifies that tapping the post card's Share button invokes share_plus with
// the EXACT spec payload:
//   "Check out this local poll on Polyticks: [Post Title]... Read more:
//    https://polyticks.app/post/{post_id}"
//

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/models/models.dart';
import 'package:polyticks/widgets/post_card.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// Captures every share() invocation instead of hitting a real platform.
class _CapturingSharePlatform extends SharePlatform {
  final List<ShareParams> calls = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return ShareResult.unavailable;
  }
}

void main() {
  // MUST be installed before SharePlus.instance is first touched, because
  // SharePlus.instance captures SharePlatform.instance lazily-once.
  final fake = _CapturingSharePlatform();
  SharePlatform.instance = fake;

  Future<void> pumpCardWith(WidgetTester tester, Post post) async {
    final user = AppUser(
      id: 'u2',
      displayName: 'U2',
      role: UserRole.janta,
      avatarColor: '#3B82F6',
      email: 'u2@test.polyticks.app',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostCard(post: post, currentUser: user),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('T5.1: share tap emits the EXACT spec payload (long title '
      'truncated to 50 chars)', (tester) async {
    final post = Post(
      id: 'aa000000-0000-0000-0000-000000000001',
      partyId: 'p1',
      content:
          'Poll post: which ward project should get funding first this quarter?',
      createdAt: DateTime(2026, 8, 22),
      likeCount: 0,
      commentCount: 0,
      type: PostType.standard,
    );
    await pumpCardWith(tester, post);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(fake.calls, hasLength(1));
    expect(
      fake.calls.single.text,
      'Check out this local poll on Polyticks: '
      'Poll post: which ward project should get funding f...'
      ' Read more: https://polyticks.app/post/aa000000-0000-0000-0000-000000000001',
    );
  });

  testWidgets('T5.1b: short post content is used verbatim as the title',
      (tester) async {
    fake.calls.clear();
    final post = Post(
      id: 'bb000000-0000-0000-0000-000000000001',
      partyId: 'p1',
      content: 'Short and sweet',
      createdAt: DateTime(2026, 8, 22),
      likeCount: 0,
      commentCount: 0,
      type: PostType.standard,
    );
    await pumpCardWith(tester, post);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(fake.calls, hasLength(1));
    expect(
      fake.calls.single.text,
      'Check out this local poll on Polyticks: Short and sweet'
      '... Read more: https://polyticks.app/post/bb000000-0000-0000-0000-000000000001',
    );
  });
}
