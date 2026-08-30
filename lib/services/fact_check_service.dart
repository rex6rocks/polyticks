// ─────────────────────────────────────────────
//  Polyticks – Fact Check & Community Notes Service
// ─────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../core/exceptions.dart';
import '../models/models.dart';
import '../data/mock_data.dart';

class FactCheckService {
  // Singleton instance
  static final FactCheckService instance = FactCheckService._internal();
  FactCheckService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ── SIMULATION STATE ──
  static String simulatedUserId = 'm1'; // Default: Sneha Patel (verified partyMember)
  static final List<Map<String, dynamic>> _simulatedFactChecks = [];
  static final List<Map<String, dynamic>> _simulatedVotes = [];
  static bool _simulatedDataInitialized = false;

  /// Initializes the mock facts and votes when running in simulation mode.
  void _initSimulatedData() {
    if (_simulatedDataInitialized) return;

    // Seed mock community notes
    _simulatedFactChecks.addAll([
      {
        'id': 'fc1',
        'post_id': 'post1',
        'author_id': 'm1',
        'context_note': 'The Jan Suraksha Yojana is currently a draft proposal and has not yet been approved by the central cabinet.',
        'source_links': ['https://example.com/healthcare-draft-report'],
        'upvotes': 12,
        'downvotes': 2,
        'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'profiles': {
          'username': 'sneha_patel',
          'is_verified': true,
        }
      },
      {
        'id': 'fc2',
        'post_id': 'post2',
        'author_id': 'm2',
        'context_note': 'This security document is the 2024 draft and not the finalized 2026 version.',
        'source_links': ['https://example.com/security-manifesto-2024'],
        'upvotes': 5,
        'downvotes': 8,
        'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
        'profiles': {
          'username': 'vikram_singh',
          'is_verified': true,
        }
      }
    ]);

    // Seed mock votes
    _simulatedVotes.addAll([
      {
        'fact_check_id': 'fc1',
        'voter_id': 'm2',
        'vote_type': 'upvote',
      },
      {
        'fact_check_id': 'fc1',
        'voter_id': 'm3',
        'vote_type': 'upvote',
      },
      {
        'fact_check_id': 'fc2',
        'voter_id': 'm1',
        'vote_type': 'downvote',
      }
    ]);

    _simulatedDataInitialized = true;
  }

  // ── CORE METHODS ──

  /// Queries `fact_checks` table with author profiles and vote maps.
  Future<List<Map<String, dynamic>>> fetchNotesForPost(String postId) async {
    if (AppConfig.isSupabaseConfigured) {
      try {
        final response = await _client
            .from('fact_checks')
            .select('''
              id, post_id, author_id, context_note, source_links, upvotes, downvotes, created_at,
              profiles:author_id (username, is_verified),
              fact_check_votes (voter_id, vote_type)
            ''')
            .eq('post_id', postId)
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } on PostgrestException catch (e) {
        throw RlsExceptionMapper.mapPostgrestException(e);
      } catch (e) {
        throw UnknownSecurityException(message: e.toString());
      }
    } else {
      _initSimulatedData();

      // Filter notes for the given post
      final notes = _simulatedFactChecks
          .where((fc) => fc['post_id'] == postId)
          .map((fc) {
            // Find votes for this note
            final noteVotes = _simulatedVotes
                .where((v) => v['fact_check_id'] == fc['id'])
                .map((v) => {
                      'voter_id': v['voter_id'],
                      'vote_type': v['vote_type'],
                    })
                .toList();

            return {
              ...fc,
              'fact_check_votes': noteVotes,
            };
          })
          .toList();

      // Sort by created_at descending
      notes.sort((a, b) => b['created_at'].compareTo(a['created_at']));
      return notes;
    }
  }

  /// Inserts a new entry into `fact_checks`.
  Future<void> submitFactCheck({
    required String postId,
    required String contextNote,
    required List<String> sourceLinks,
  }) async {
    if (contextNote.trim().isEmpty) {
      throw const UnknownSecurityException(
        message: 'Check violation: empty context note is not allowed.',
        code: '23514',
      );
    }

    if (AppConfig.isSupabaseConfigured) {
      try {
        final user = _client.auth.currentUser;
        if (user == null) {
          throw const VerificationRequiredException(
            message: 'Auth exception: user must be authenticated.',
          );
        }

        await _client.from('fact_checks').insert({
          'post_id': postId,
          'author_id': user.id,
          'context_note': contextNote.trim(),
          'source_links': sourceLinks.where((s) => s.trim().isNotEmpty).toList(),
        });
      } on PostgrestException catch (e) {
        throw RlsExceptionMapper.mapPostgrestException(e);
      } catch (e) {
        if (e is PolyticksDomainException) rethrow;
        throw UnknownSecurityException(message: e.toString());
      }
    } else {
      _initSimulatedData();

      // Resolve user profile
      final user = userById(simulatedUserId);
      if (user == null) {
        throw Exception('Simulated user with ID $simulatedUserId not found.');
      }

      // Check verification & role criteria (must be verified and admin/party/partyMember)
      final allowedRoles = [UserRole.partyMember, UserRole.party, UserRole.admin];
      final isAllowed = user.isVerified && allowedRoles.contains(user.role);

      if (!isAllowed) {
        throw const VerificationRequiredException();
      }

      // Check rate-limit (max 5 per 24 hours)
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final recentSubmissions = _simulatedFactChecks.where((fc) {
        if (fc['author_id'] != user.id) return false;
        final createdAt = DateTime.parse(fc['created_at']);
        return createdAt.isAfter(cutoff);
      }).length;

      if (recentSubmissions >= 5) {
        throw const RateLimitExceededException();
      }

      // Safe to insert
      final newId = 'fc_sim_${DateTime.now().millisecondsSinceEpoch}';
      _simulatedFactChecks.add({
        'id': newId,
        'post_id': postId,
        'author_id': user.id,
        'context_note': contextNote.trim(),
        'source_links': sourceLinks.where((s) => s.trim().isNotEmpty).toList(),
        'upvotes': 0,
        'downvotes': 0,
        'created_at': DateTime.now().toIso8601String(),
        'profiles': {
          'username': user.displayName,
          'is_verified': user.isVerified,
        }
      });
    }
  }

  /// Upserts into `fact_check_votes`.
  Future<void> voteOnNote({
    required String noteId,
    required String voteType,
  }) async {
    if (voteType != 'upvote' && voteType != 'downvote') {
      throw const UnknownSecurityException(
        message: 'Check violation: invalid vote type.',
        code: '23514',
      );
    }

    if (AppConfig.isSupabaseConfigured) {
      try {
        final user = _client.auth.currentUser;
        if (user == null) {
          throw const VerificationRequiredException(
            message: 'Auth exception: user must be authenticated.',
          );
        }

        // Upsert the vote record
        await _client.from('fact_check_votes').upsert({
          'fact_check_id': noteId,
          'voter_id': user.id,
          'vote_type': voteType,
        });
      } on PostgrestException catch (e) {
        throw RlsExceptionMapper.mapPostgrestException(e);
      } catch (e) {
        if (e is PolyticksDomainException) rethrow;
        throw UnknownSecurityException(message: e.toString());
      }
    } else {
      _initSimulatedData();

      // Resolve user profile
      final user = userById(simulatedUserId);
      if (user == null) {
        throw Exception('Simulated user with ID $simulatedUserId not found.');
      }

      // Check verification & role criteria
      final allowedRoles = [UserRole.partyMember, UserRole.party, UserRole.admin];
      final isAllowed = user.isVerified && allowedRoles.contains(user.role);

      if (!isAllowed) {
        throw const VerificationRequiredException();
      }

      // Check if note exists
      final noteIndex = _simulatedFactChecks.indexWhere((fc) => fc['id'] == noteId);
      if (noteIndex == -1) {
        throw Exception('Fact-check note with ID $noteId not found.');
      }

      final note = _simulatedFactChecks[noteIndex];
      final previousVoteIndex = _simulatedVotes.indexWhere(
        (v) => v['fact_check_id'] == noteId && v['voter_id'] == user.id,
      );

      if (previousVoteIndex != -1) {
        final previousVote = _simulatedVotes[previousVoteIndex];
        if (previousVote['vote_type'] == voteType) {
          // Attempting to cast same vote: simulated database unique constraint violation or duplicate vote error
          throw const DuplicateVoteException();
        } else {
          // Vote flip: update counters
          if (voteType == 'upvote') {
            note['upvotes'] = (note['upvotes'] as int) + 1;
            note['downvotes'] = ((note['downvotes'] as int) - 1).clamp(0, 999999);
          } else {
            note['downvotes'] = (note['downvotes'] as int) + 1;
            note['upvotes'] = ((note['upvotes'] as int) - 1).clamp(0, 999999);
          }
          previousVote['vote_type'] = voteType;
        }
      } else {
        // New vote insert
        if (voteType == 'upvote') {
          note['upvotes'] = (note['upvotes'] as int) + 1;
        } else {
          note['downvotes'] = (note['downvotes'] as int) + 1;
        }
        _simulatedVotes.add({
          'fact_check_id': noteId,
          'voter_id': user.id,
          'vote_type': voteType,
        });
      }
    }
  }

  /// Retracts a vote on a fact-check note (simulated or real).
  Future<void> retractVote({required String noteId}) async {
    if (AppConfig.isSupabaseConfigured) {
      try {
        final user = _client.auth.currentUser;
        if (user == null) {
          throw const VerificationRequiredException(
            message: 'Auth exception: user must be authenticated.',
          );
        }

        await _client
            .from('fact_check_votes')
            .delete()
            .eq('fact_check_id', noteId)
            .eq('voter_id', user.id);
      } on PostgrestException catch (e) {
        throw RlsExceptionMapper.mapPostgrestException(e);
      } catch (e) {
        if (e is PolyticksDomainException) rethrow;
        throw UnknownSecurityException(message: e.toString());
      }
    } else {
      _initSimulatedData();

      // Resolve user profile
      final user = userById(simulatedUserId);
      if (user == null) {
        throw Exception('Simulated user with ID $simulatedUserId not found.');
      }

      final noteIndex = _simulatedFactChecks.indexWhere((fc) => fc['id'] == noteId);
      if (noteIndex == -1) return;

      final note = _simulatedFactChecks[noteIndex];
      final voteIndex = _simulatedVotes.indexWhere(
        (v) => v['fact_check_id'] == noteId && v['voter_id'] == user.id,
      );

      if (voteIndex != -1) {
        final vote = _simulatedVotes[voteIndex];
        if (vote['vote_type'] == 'upvote') {
          note['upvotes'] = ((note['upvotes'] as int) - 1).clamp(0, 999999);
        } else {
          note['downvotes'] = ((note['downvotes'] as int) - 1).clamp(0, 999999);
        }
        _simulatedVotes.removeAt(voteIndex);
      }
    }
  }

  /// Helper to clear simulated data (primarily for testing purposes).
  void clearSimulatedData() {
    _simulatedFactChecks.clear();
    _simulatedVotes.clear();
    _simulatedDataInitialized = false;
  }
}
