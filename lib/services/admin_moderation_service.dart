// ─────────────────────────────────────────────
//  Polyticks – Admin Moderation Service
// ─────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../models/models.dart';
import '../data/mock_data.dart';

/// Service for admin moderation operations, including fetching flagged posts
/// and resolving reports (approve/restore or hard-delete).
class AdminModerationService {
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Fetches posts flagged for moderation (either hidden, disputed, or reported).
  Future<List<Map<String, dynamic>>> fetchFlaggedPosts() async {
    if (AppConfig.isSupabaseConfigured) {
      try {
        final response = await _supabase
            .from('posts')
            .select('''
              id, content, media_url, author_id, like_count, dislike_count,
              is_hidden, flagged_reason, created_at, fact_check_status,
              profiles:author_id (username)
            ''')
            .or('is_hidden.eq.true,fact_check_status.eq.under_review,fact_check_status.eq.disputed,fact_check_status.eq.auto_hidden')
            .order('created_at', ascending: false);

        final posts = List<Map<String, dynamic>>.from(response);

        // Enrich with report counts + SLA-breach age (migration 07).
        for (final post in posts) {
          final postId = post['id'] as String;
          final reports = await _supabase
              .from('reports')
              .select('id, status')
              .eq('post_id', postId);
          post['report_count'] = (reports as List).length;

          // SLA breach age in hours, if a breach event exists for this post.
          try {
            final breach = await _supabase
                .from('sla_events')
                .select('created_at')
                .eq('post_id', postId)
                .eq('event_type', 'sla_breach')
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (breach != null && breach['created_at'] != null) {
              final detected = DateTime.parse(breach['created_at'] as String);
              post['sla_breach_age_hours'] =
                  DateTime.now().toUtc().difference(detected).inHours;
            }
          } catch (_) {
            // sla_events may not exist yet if migration 07 hasn't run.
          }
        }
        return posts;
      } catch (e) {
        throw Exception('Failed to fetch flagged posts: $e');
      }
    } else {
      // Simulation / mock fallback
      return mockPosts
          .where((p) => p.isHidden || p.factCheckStatus != FactCheckStatus.none)
          .map((p) {
        return {
          'id': p.id,
          'content': p.content,
          'media_url': null,
          'author_id': p.authorId ?? 'u1',
          'author_username': p.authorId != null ? 'party_rep' : 'official',
          'like_count': p.likeCount,
          'dislike_count': p.dislikeCount,
          'is_hidden': p.isHidden,
          'flagged_reason': p.flaggedReason ?? 'Civic dispute reported by voters',
          'created_at': p.createdAt.toIso8601String(),
          'fact_check_status': p.factCheckStatus.toDbValue(),
        };
      }).toList();
    }
  }

  /// Resolves a report for a post: approve restores visibility (and resolves
  /// pending reports); reject keeps the post hidden with a logged reason and
  /// marks pending reports rejected.
  Future<void> resolveReport({
    required String postId,
    required bool approveRestore,
  }) async {
    if (AppConfig.isSupabaseConfigured) {
      try {
        if (approveRestore) {
          // Approve: restore visibility and promote to verified context.
          await _supabase.from('posts').update({
            'is_hidden': false,
            'flagged_reason': null,
            'fact_check_status': 'verified_context',
          }).eq('id', postId);

          // Mark all pending reports on this post as resolved (audit trail).
          await _supabase
              .from('reports')
              .update({'status': 'resolved'})
              .eq('post_id', postId)
              .eq('status', 'pending');
        } else {
          // Reject: per v2 blueprint the post is KEPT hidden (never un-hidden
          // automatically, never silently deleted) and the decision is logged.
          await _supabase.from('posts').update({
            'is_hidden': true,
            'flagged_reason':
                'Rejected by admin moderation at ${DateTime.now().toUtc().toIso8601String()}',
          }).eq('id', postId)
              .inFilter('fact_check_status',
                  ['auto_hidden', 'under_review', 'disputed', 'none']);

          // Mark all pending reports as rejected (audit trail).
          await _supabase
              .from('reports')
              .update({'status': 'rejected'})
              .eq('post_id', postId)
              .eq('status', 'pending');
        }
      } catch (e) {
        throw Exception('Failed to resolve report for post $postId: $e');
      }
    } else {
      final postIndex = mockPosts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        if (approveRestore) {
          mockPosts[postIndex].isHidden = false;
          mockPosts[postIndex].factCheckStatus = FactCheckStatus.verifiedContext;
          mockPosts[postIndex].flaggedReason = null;
        } else {
          // Simulation mirrors production semantics: keep hidden, log reason.
          mockPosts[postIndex].isHidden = true;
          mockPosts[postIndex].flaggedReason =
              'Rejected by admin moderation at ${DateTime.now().toUtc().toIso8601String()}';
        }
      }
    }
  }

  /// Convenience method: Approve & unhide content
  Future<void> approveContent(String postId) async {
    await resolveReport(postId: postId, approveRestore: true);
  }

  /// Convenience method: Reject & delete content
  Future<void> rejectContent(String postId) async {
    await resolveReport(postId: postId, approveRestore: false);
  }
}
