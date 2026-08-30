import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../data/mock_data.dart';
import '../services/fact_check_service.dart';
import '../services/supabase_service.dart';

part 'fact_check_provider.g.dart';

// FactCheckState class
class FactCheckState {
  final FactCheckStatus status;
  final bool isBannerVisible;
  final String? communityNotePreview;
  final List<String>? sources;

  FactCheckState({
    required this.status,
    this.isBannerVisible = false,
    this.communityNotePreview,
    this.sources,
  });
}

// FactCheckNotifier with @riverpod annotation
@riverpod
class FactCheckNotifier extends _$FactCheckNotifier {
  SupabaseClient? get _supabase => SupabaseService.instance.client;

  @override
  Future<FactCheckState> build(String postId) async {
    if (!SupabaseService.instance.isRealSupabase || _supabase == null) {
      final post = mockPosts.firstWhere(
        (p) => p.id == postId,
        orElse: () => Post(
          id: postId,
          partyId: 'p1',
          content: '',
          createdAt: DateTime.now(),
          likeCount: 0,
          dislikeCount: 0,
          commentCount: 0,
          type: PostType.standard,
        ),
      );

      // Check simulated fact checks
      final notes = await FactCheckService.instance.fetchNotesForPost(postId);
      final notePreview =
          notes.isNotEmpty ? notes.first['context_note'] as String? : null;

      return FactCheckState(
        status: post.factCheckStatus,
        isBannerVisible: post.factCheckStatus == FactCheckStatus.underReview,
        communityNotePreview: notePreview,
        sources: post.factCheckSources,
      );
    }

    // Set up a real-time subscription to listen for changes to the post's fact_check_status
    _setupReactionStream(postId);

    // Fetch the initial fact-check status for the post
    try {
      final response = await _supabase!
          .from('posts')
          .select('fact_check_status')
          .eq('id', postId)
          .maybeSingle();

      final status =
          _mapStatus(response?['fact_check_status']?.toString() ?? '');

      return FactCheckState(
        status: status,
        isBannerVisible: status == FactCheckStatus.underReview,
        communityNotePreview: null,
      );
    } catch (_) {
      return FactCheckState(
        status: FactCheckStatus.none,
        isBannerVisible: false,
        communityNotePreview: null,
      );
    }
  }

  // Map the string status from Supabase to the FactCheckStatus enum
  FactCheckStatus _mapStatus(String status) {
    return FactCheckStatus.fromString(status);
  }

  // Set up a real-time subscription to listen for changes to the post's fact_check_status
  void _setupReactionStream(String postId) {
    if (!SupabaseService.instance.isRealSupabase || _supabase == null) {
      return;
    }

    try {
      final channel = _supabase!
          .channel('post_fact_check_changes_$postId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'posts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: postId,
            ),
            callback: (payload) async {
              final newStatus = _mapStatus(
                  payload.newRecord['fact_check_status']?.toString() ?? '');
              final currentState = await future;

              // Update the state if the status has changed to under_review
              if (newStatus == FactCheckStatus.underReview) {
                state = AsyncValue.data(
                  FactCheckState(
                    status: newStatus,
                    isBannerVisible: true,
                    communityNotePreview: currentState.communityNotePreview,
                  ),
                );
              }
            },
          )
          .subscribe();

      // Clean up channel subscription when the widget is disposed
      ref.onDispose(() {
        _supabase?.removeChannel(channel);
      });
    } catch (_) {}
  }

  // Update the community note preview and sources
  Future<void> updateCommunityNote(String note, List<String> sources) async {
    final currentState = await future;
    state = AsyncValue.data(
      FactCheckState(
        status: currentState.status,
        isBannerVisible: currentState.isBannerVisible,
        communityNotePreview: note,
        sources: sources,
      ),
    );
  }
}
