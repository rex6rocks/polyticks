// lib/providers/moderation_provider.dart

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/models.dart';
import '../services/admin_moderation_service.dart';

part 'moderation_provider.g.dart';

@immutable
class ModerationState {
  final List<ModerationQueueItem> queue;
  final ModerationFilter filter;
  final bool isActionInProgress;
  final String? activeError;
  final DateTime lastRefreshed;

  const ModerationState({
    this.queue = const [],
    this.filter = const ModerationFilter(),
    this.isActionInProgress = false,
    this.activeError,
    required this.lastRefreshed,
  });

  /// Returns items filtered and sorted by SLA urgency countdown (critical & breached first).
  List<ModerationQueueItem> get filteredQueue {
    return queue.where((item) {
      if (filter.showOnlyPending && item.isHidden) return false;
      if (filter.urgencyFilter != null && item.slaUrgency != filter.urgencyFilter) return false;
      if (filter.statusFilter != null && item.factCheckStatus != filter.statusFilter) return false;
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final q = filter.searchQuery!.toLowerCase();
        final matchContent = item.postContent.toLowerCase().contains(q);
        final matchReason = item.reason.toLowerCase().contains(q);
        final matchAuthor = (item.authorUsername ?? '').toLowerCase().contains(q);
        if (!matchContent && !matchReason && !matchAuthor) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.slaDeadline.compareTo(b.slaDeadline)); // Shortest SLA remaining first
  }

  ModerationState copyWith({
    List<ModerationQueueItem>? queue,
    ModerationFilter? filter,
    bool? isActionInProgress,
    String? Function()? activeError,
    DateTime? lastRefreshed,
  }) {
    return ModerationState(
      queue: queue ?? this.queue,
      filter: filter ?? this.filter,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      activeError: activeError != null ? activeError() : this.activeError,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }
}

@riverpod
class ModerationNotifier extends _$ModerationNotifier {
  final AdminModerationService _moderationService = AdminModerationService();

  @override
  Future<ModerationState> build() async {
    final queue = await _fetchQueue();
    return ModerationState(
      queue: queue,
      lastRefreshed: DateTime.now(),
    );
  }

  Future<List<ModerationQueueItem>> _fetchQueue() async {
    try {
      final posts = await _moderationService.fetchFlaggedPosts();
      return posts.map((post) {
        final slaDeadline = DateTime.parse(post['created_at'] as String).add(const Duration(hours: 24));

        return ModerationQueueItem(
          reportId: post['id'] as String,
          postId: post['id'] as String,
          postContent: post['content'] as String,
          authorId: post['author_id'] as String? ?? '',
          authorUsername: post['author_username'] as String?,
          reporterId: post['reporter_id'] as String? ?? '',
          reason: post['flagged_reason'] as String? ?? 'Unknown',
          totalReportsOnPost: post['total_reports'] as int? ?? 1,
          likeCount: post['like_count'] as int? ?? 0,
          dislikeCount: post['dislike_count'] as int? ?? 0,
          slaDeadline: slaDeadline,
          isHidden: post['is_hidden'] as bool? ?? false,
          factCheckStatus: _mapStatus(post['fact_check_status'] as String? ?? ''),
          firstReportedAt: DateTime.parse(post['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch moderation queue: $e');
    }
  }

  FactCheckStatus _mapStatus(String status) {
    switch (status) {
      case 'none':
        return FactCheckStatus.none;
      case 'under_review':
        return FactCheckStatus.underReview;
      case 'verified_context':
        return FactCheckStatus.verifiedContext;
      case 'disputed':
        return FactCheckStatus.disputed;
      case 'auto_hidden':
        return FactCheckStatus.autoHidden;
      default:
        return FactCheckStatus.none;
    }
  }

  Future<void> refreshQueue() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final queue = await _fetchQueue();
      final currentState = await future;
      return currentState.copyWith(
        queue: queue,
        lastRefreshed: DateTime.now(),
      );
    });
  }

  Future<void> resolveReport(String postId, bool approveRestore) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _moderationService.resolveReport(
        postId: postId,
        approveRestore: approveRestore,
      );
      final currentState = await future;
      return currentState.copyWith(
        queue: currentState.queue.where((item) => item.postId != postId).toList(),
        lastRefreshed: DateTime.now(),
      );
    });
  }

  void updateFilter(ModerationFilter filter) async {
    final currentState = await future;
    state = AsyncValue.data(currentState.copyWith(filter: filter));
  }
}