// ─────────────────────────────────────────────
//  Polyticks – Report Service
// ─────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../core/exceptions.dart';

class ReportService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  // In-memory simulation store for when Supabase is unconfigured
  static final List<Map<String, dynamic>> _simulatedReports = [];

  /// Submits a content report for a post.
  static Future<void> submitReport({
    required String postId,
    required String userId,
    required String reason,
    String? comment,
  }) async {
    final finalReason = comment != null && comment.trim().isNotEmpty
        ? '$reason: ${comment.trim()}'
        : reason;

    if (AppConfig.isSupabaseConfigured) {
      try {
        final currentUser = _supabase.auth.currentUser;
        final reporterId = currentUser?.id ?? userId;

        await _supabase.from('reports').insert({
          'post_id': postId,
          'reporter_id': reporterId,
          'reason': finalReason,
        });
      } on PostgrestException catch (e) {
        throw RlsExceptionMapper.mapPostgrestException(e);
      } catch (e) {
        if (e is PolyticksDomainException) rethrow;
        throw UnknownSecurityException(message: e.toString());
      }
    } else {
      _simulatedReports.add({
        'id': 'rep_${DateTime.now().millisecondsSinceEpoch}',
        'post_id': postId,
        'reporter_id': userId,
        'reason': finalReason,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Fetches all active reports for moderation.
  static Future<List<Map<String, dynamic>>> fetchPendingReports() async {
    if (AppConfig.isSupabaseConfigured) {
      try {
        final response = await _supabase.from('reports').select('''
              id, post_id, reporter_id, reason, created_at,
              posts:post_id (
                id, content, author_id, is_hidden, dislike_count, like_count, fact_check_status,
                profiles:author_id (username)
              )
            ''').order('created_at', ascending: true);

        return List<Map<String, dynamic>>.from(response);
      } on PostgrestException catch (e) {
        throw RlsExceptionMapper.mapPostgrestException(e);
      } catch (e) {
        throw UnknownSecurityException(message: e.toString());
      }
    } else {
      return List<Map<String, dynamic>>.from(_simulatedReports);
    }
  }

  /// Resolves a report by deleting the report record and optionally restoring/deleting the post.
  static Future<void> resolveReport({
    required String reportId,
    required String postId,
    required bool restorePost,
  }) async {
    if (AppConfig.isSupabaseConfigured) {
      try {
        if (restorePost) {
          await _supabase.from('posts').update({
            'is_hidden': false,
            'flagged_reason': null,
          }).eq('id', postId);
        } else {
          await _supabase.from('posts').delete().eq('id', postId);
        }
        await _supabase.from('reports').delete().eq('id', reportId);
      } on PostgrestException catch (e) {
        throw RlsExceptionMapper.mapPostgrestException(e);
      } catch (e) {
        throw UnknownSecurityException(message: e.toString());
      }
    } else {
      _simulatedReports.removeWhere((r) => r['id'] == reportId);
    }
  }
}
