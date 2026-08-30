import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class PollNotifier extends StateNotifier<Poll> {
  final SupabaseService _supabaseService;

  /// Authenticated voter id passed through to
  /// `SupabaseService.voteInPoll` (defaults to the sim-mode voter).
  final String userId;

  PollNotifier(super.poll, this._supabaseService, {this.userId = 'sim_user'});

  /// Optimistic vote: state updates IMMEDIATELY (synchronously, before the
  /// async insert resolves) so the UI switches to Results Mode instantly.
  ///
  /// Persistence + contract validation (UNIQUE(poll_id, voter_id), verified-
  /// member RLS) is delegated to `SupabaseService.voteInPoll`. On failure the
  /// ENTIRE pre-vote state is restored and `false` is returned so the UI can
  /// show the failure SnackBar
  /// ("Action failed: Ensure you are a verified community member").
  Future<bool> vote(String optionId) async {
    final previousState = state;

    // Optimistic Update (runs before any await)
    final updatedOptions = state.options.map((option) {
      if (option.id == optionId) {
        return PollOption(
            id: option.id, text: option.text, votes: option.votes + 1);
      }
      return option;
    }).toList();

    state = Poll(
      id: state.id,
      partyId: state.partyId,
      question: state.question,
      options: updatedOptions,
      endsAt: state.endsAt,
      votedOptionId: optionId,
    );

    final ok = await _supabaseService.voteInPoll(userId, state.id, optionId);
    if (!ok) {
      // Revert on error (double vote / RLS denial / network failure)
      state = previousState;
      return false;
    }
    return true;
  }
}

final pollProvider =
    StateNotifierProvider.family<PollNotifier, Poll, Poll>((ref, poll) {
  return PollNotifier(poll, SupabaseService.instance);
});
