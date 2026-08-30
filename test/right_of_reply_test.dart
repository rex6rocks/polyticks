// ─────────────────────────────────────────────
//  Polyticks V4.0 – Right-of-Reply Service Tests (B11)
// ─────────────────────────────────────────────
//
//  Covers the SIMULATION-mode contract of RightOfReplyService (mirrors
//  migration 10's RLS rules):
//    * tier gate: basic orgs are rejected (ROR_TIER_REQUIRED)
//    * length validation: 20–2000 chars
//    * submit → published; fetchPublishedForPost returns it
//    * revise replaces the statement (unique per org+post)
//    * withdraw hides the public reply
//    * open disputes list reflects mock posts under review
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/config.dart';
import 'package:polyticks/core/exceptions.dart';
import 'package:polyticks/data/mock_data.dart';
import 'package:polyticks/models/models.dart';
import 'package:polyticks/services/right_of_reply_service.dart';
import 'package:polyticks/services/subscription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AppConfig.forceTestMode = true;
  });

  setUp(() async {
    RightOfReplyService.resetSimulation();
    // Seed an active gold subscription for the test org so tier gates pass.
    // (SubscriptionService simulation store is keyed by currentUserId, which
    // is null in tests → 'sim-org'; use that id for submits.)
    await SubscriptionService.startUpgrade(OrgTier.gold);
  });

  /// Flags a mock party post so the portal has an open dispute.
  Post flagDisputedMockPost() {
    final post = mockPosts.firstWhere((p) => p.partyId.isNotEmpty);
    post.factCheckStatus = FactCheckStatus.disputed;
    return post;
  }

  test('open disputes lists mock posts under fact-check scrutiny', () async {
    final flagged = flagDisputedMockPost();
    final disputes =
        await RightOfReplyService.fetchOpenDisputes(flagged.partyId);
    expect(disputes.length, greaterThanOrEqualTo(1));
    expect(disputes.first.post.id, flagged.id);
    expect(disputes.first.dbStatus, 'disputed');
    expect(disputes.first.hasReply, isFalse);
  });

  test('orgs without disputes get an empty list', () async {
    expect(await RightOfReplyService.fetchOpenDisputes('no-such-org'), isEmpty);
  });

  test('submit publishes a statement visible via fetchPublishedForPost',
      () async {
    final disputed = flagDisputedMockPost();
    final postId = disputed.id;

    final reply = await RightOfReplyService.submitReply(
      orgId: 'sim-org',
      postId: postId,
      statement:
          'These figures come from the official EC release dated March 2026.',
    );
    expect(reply.isPublished, isTrue);

    final public = await RightOfReplyService.fetchPublishedForPost(postId);
    expect(public, isNotNull);
    expect(public!.statement, contains('EC release'));
  });

  test('statements shorter than 20 chars are rejected', () async {
    expect(
      () => RightOfReplyService.submitReply(
          orgId: 'sim-org', postId: 'p1', statement: 'too short'),
      throwsA(isA<PolyticksDomainException>()),
    );
  });

  test('revise replaces the single per-post statement', () async {
    const postId = 'mock-post-1';
    await RightOfReplyService.submitReply(
        orgId: 'sim-org', postId: postId, statement: 'First official response with adequate length.');
    await RightOfReplyService.submitReply(
        orgId: 'sim-org', postId: postId, statement: 'Revised official response with adequate length.');

    final public = await RightOfReplyService.fetchPublishedForPost(postId);
    expect(public!.statement, startsWith('Revised'));
  });

  test('withdraw hides the public reply', () async {
    const postId = 'mock-post-2';
    await RightOfReplyService.submitReply(
        orgId: 'sim-org', postId: postId, statement: 'Statement to be withdrawn shortly.');
    await RightOfReplyService.withdrawReply(orgId: 'sim-org', postId: postId);

    expect(await RightOfReplyService.fetchPublishedForPost(postId), isNull);
  });

  test('withdraw without a reply throws ROR_NOT_FOUND', () async {
    expect(
      () => RightOfReplyService.withdrawReply(
          orgId: 'sim-org', postId: 'never-submitted'),
      throwsA(isA<PolyticksDomainException>()),
    );
  });

  test('basic-tier orgs are rejected with ROR_TIER_REQUIRED', () async {
    // Reset drops the seeded gold subscription → tier falls back to basic.
    RightOfReplyService.resetSimulation();
    SubscriptionService.resetSimulation();
    const postId = 'mock-post-3';
    expect(
      () => RightOfReplyService.submitReply(
          orgId: 'sim-org',
          postId: postId,
          statement: 'Attempted statement that is definitely long enough.'),
      throwsA(predicate((e) =>
          e is PolyticksDomainException && e.code == 'ROR_TIER_REQUIRED')),
    );
  });
}
