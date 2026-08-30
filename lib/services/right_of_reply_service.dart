// ─────────────────────────────────────────────
//  Polyticks V4.0 – Right-of-Reply Service (B11)
// ─────────────────────────────────────────────
//
//  Paid-org official statements on disputed content.
//  Server rules (migration 10) enforced client-side as UX gates:
//    * one reply per (org, post); revisable/withdrawable by the org
//    * INSERT/UPDATE requires active tier (active_org_tier() IS NOT NULL)
//    * published replies are public; drafts org-only
//
//  SIMULATION MODE mirrors these semantics in-memory over the mock post
//  table (same pattern as SubscriptionService / AnalyticsService).
import 'package:flutter/foundation.dart';
import '../core/exceptions.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import 'supabase_service.dart';
import 'subscription_service.dart';

class OfficialReply {
  final String id;
  final String orgId;
  final String postId;
  final String statement;
  final String status; // draft | published | withdrawn

  const OfficialReply({
    required this.id,
    required this.orgId,
    required this.postId,
    required this.statement,
    required this.status,
  });

  factory OfficialReply.fromRow(Map<String, dynamic> row) => OfficialReply(
        id: row['id'] as String,
        orgId: row['org_id'] as String,
        postId: row['post_id'] as String,
        statement: row['official_statement'] as String,
        status: row['status'] as String? ?? 'draft',
      );

  bool get isPublished => status == 'published';
}

class DisputedPost {
  final Post post;
  final String dbStatus; // 'under_review' | 'disputed'
  final bool hasReply;
  const DisputedPost({
    required this.post,
    required this.dbStatus,
    this.hasReply = false,
  });
}

class RightOfReplyService {
  RightOfReplyService._();

  // Simulation store: 'orgId|postId' → reply record.
  static final Map<String, Map<String, dynamic>> _simulated = {};

  static String _key(String orgId, String postId) => '$orgId|$postId';

  // ── OPEN DISPUTES (portal queue) ─────────────────────────────────────────

  /// Posts authored by [orgId] currently under fact-check scrutiny
  /// (under_review / disputed), annotated with existing-reply state.
  static Future<List<DisputedPost>> fetchOpenDisputes(String orgId) async {
    final service = SupabaseService.instance;
    if (!service.isRealSupabase) {
      // Simulation: derive from mock posts + simulated replies.
      return mockPosts
          .where((p) =>
              p.partyId == orgId &&
              (p.factCheckStatus == FactCheckStatus.underReview ||
                  p.factCheckStatus == FactCheckStatus.disputed))
          .map((p) {
        final dbStatus = p.factCheckStatus == FactCheckStatus.disputed
            ? 'disputed'
            : 'under_review';
        return DisputedPost(
          post: p,
          dbStatus: dbStatus,
          hasReply: _simulated.containsKey(_key(orgId, p.id)) &&
              _simulated[_key(orgId, p.id)]!['status'] != 'withdrawn',
        );
      }).toList();
    }
    // Live mode: fall back to the authenticated user for mock ids.
    if (!SupabaseService.isUuid(orgId)) orgId = service.currentUserId ?? '';
    if (!SupabaseService.isUuid(orgId)) return [];
    try {
      final rows = await service.client!
          .from('posts')
          .select('id, content, created_at, fact_check_status, '
              'right_of_replies(id, status)')
          .eq('author_id', orgId)
          .inFilter('fact_check_status', ['under_review', 'disputed']);
      return rows.map<DisputedPost>((row) {
        final replies = row['right_of_replies'] as List?;
        final hasLive = replies != null &&
            replies.isNotEmpty &&
            (replies.first['status'] as String?) != 'withdrawn';
        // Reconstruct a lightweight mock Post for UI reuse.
        return DisputedPost(
          post: Post(
            id: row['id'] as String,
            partyId: orgId,
            content: row['content'] as String? ?? '',
            createdAt:
                DateTime.tryParse(row['created_at'] as String? ?? '') ??
                    DateTime.now(),
            likeCount: 0,
            commentCount: 0,
            type: PostType.standard,
            factCheckStatus: FactCheckStatus.fromString(
                row['fact_check_status'] as String? ?? 'none'),
          ),
          dbStatus: row['fact_check_status'] as String,
          hasReply: hasLive,
        );
      }).toList();
    } catch (e) {
      debugPrint('fetchOpenDisputes failed: $e');
      return [];
    }
  }

  // ── SUBMIT / REVISE ──────────────────────────────────────────────────────

  /// Creates or replaces the org's official statement on [postId].
  /// Published immediately when [publish] is true, else stored as draft.
  static Future<OfficialReply> submitReply({
    required String orgId,
    required String postId,
    required String statement,
    bool publish = true,
  }) async {
    final trimmed = statement.trim();
    if (trimmed.length < 20 || trimmed.length > 2000) {
      throw const RightOfReplyException(
        message: 'Statement must be 20–2000 characters.',
        userFriendlyMessage:
            'Official statements must be between 20 and 2000 characters.',
        code: 'ROR_INVALID_LENGTH',
      );
    }

    // Tier gate (mirrors RLS: active_org_tier() IS NOT NULL).
    final tier = await SubscriptionService.fetchActiveTier(orgId);
    if (tier == OrgTier.basic) {
      throw const RightOfReplyException(
        message: 'Right of Reply requires an active paid subscription.',
        userFriendlyMessage:
            'The Right-of-Reply portal is available to Gold and Platinum organizations. Upgrade to respond officially.',
        code: 'ROR_TIER_REQUIRED',
      );
    }

    final service = SupabaseService.instance;
    final status = publish ? 'published' : 'draft';

    if (!service.isRealSupabase) {
      final existing = _simulated[_key(orgId, postId)];
      _simulated[_key(orgId, postId)] = {
        'id': existing?['id'] as String? ?? 'ror-${DateTime.now().microsecondsSinceEpoch}',
        'org_id': orgId,
        'post_id': postId,
        'official_statement': trimmed,
        'status': status,
      };
      debugPrint('RoR SIMULATION: $status reply on $postId');
      return OfficialReply.fromRow(_simulated[_key(orgId, postId)]!);
    }

    try {
      final response = await service.client!
          .from('right_of_replies')
          .upsert({
            'org_id': orgId,
            'post_id': postId,
            'official_statement': trimmed,
            'status': status,
          })
          .select()
          .single();
      return OfficialReply.fromRow(response);
    } catch (e) {
      throw RightOfReplyException(
        message: 'upsert failed: $e',
        userFriendlyMessage:
            'Could not save your official statement. Please try again.',
        code: 'ROR_SUBMIT_FAILED',
      );
    }
  }

  // ── WITHDRAW ─────────────────────────────────────────────────────────────

  static Future<void> withdrawReply({
    required String orgId,
    required String postId,
  }) async {
    final service = SupabaseService.instance;
    if (!service.isRealSupabase) {
      final key = _key(orgId, postId);
      if (!_simulated.containsKey(key)) {
        throw const RightOfReplyException(
          message: 'No reply to withdraw.',
          userFriendlyMessage: 'No official statement exists for this post.',
          code: 'ROR_NOT_FOUND',
        );
      }
      _simulated[key]!['status'] = 'withdrawn';
      debugPrint('RoR SIMULATION: withdrawn on $postId');
      return;
    }
    try {
      await service.client!
          .from('right_of_replies')
          .update({'status': 'withdrawn'})
          .eq('org_id', orgId)
          .eq('post_id', postId);
    } catch (e) {
      throw RightOfReplyException(
        message: 'withdraw failed: $e',
        userFriendlyMessage: 'Could not withdraw the statement. Please retry.',
        code: 'ROR_WITHDRAW_FAILED',
      );
    }
  }

  // ── PUBLIC FETCH (post-card banner) ──────────────────────────────────────

  /// Published reply for a post, or null. Public — no tier requirement.
  static Future<OfficialReply?> fetchPublishedForPost(String postId) async {
    final service = SupabaseService.instance;
    if (!service.isRealSupabase) {
      for (final row in _simulated.values) {
        if (row['post_id'] == postId && row['status'] == 'published') {
          return OfficialReply.fromRow(row);
        }
      }
      return null;
    }
    try {
      // Live mode: post ids from mock data aren't UUIDs — nothing to fetch.
      if (!SupabaseService.isUuid(postId)) return null;
      final rows = await service.client!
          .from('right_of_replies')
          .select()
          .eq('post_id', postId)
          .eq('status', 'published')
          .limit(1);
      if (rows.isEmpty) return null;
      return OfficialReply.fromRow(rows.first);
    } catch (e) {
      debugPrint('fetchPublishedForPost failed: $e');
      return null;
    }
  }

  /// Test hook: reset simulation state between tests.
  @visibleForTesting
  static void resetSimulation() => _simulated.clear();
}
