import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../data/mock_data.dart';
import '../config.dart';
import 'ai_moderation_service.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient? _client;
  bool _isSimulation = true;

  /// Public getter for the underlying Supabase client.
  ///
  /// The service internally holds a nullable [_client] which is only
  /// instantiated when real Supabase credentials are provided. Test code
  /// (and other callers) expect to access the client directly via
  /// `supabaseService.client`. Providing this getter maintains the existing
  /// encapsulation while satisfying the public API used throughout the test
  /// suite.
  SupabaseClient? get client => _client;

  /// Convenience accessor for the signed-in user's id.
  /// Null when not signed in (simulation fixtures use explicit ids).
  String? get currentUserId => _client?.auth.currentUser?.id;

  /// True when [value] is a well-formed PostgreSQL UUID.
  /// Mock data ids ('p1', 'p_u1'…) are not — callers must never send them
  /// to live queries (Postgres rejects them with 22P02).
  static bool isUuid(String? value) =>
      value != null &&
      RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(value);

  // Local simulated tables (synchronized with mock_data for instant running)
  late List<AppUser> _simulatedUsers;
  late List<Post> _simulatedPosts;
  final List<Map<String, dynamic>> _simulatedReactions = [];
  final List<Map<String, dynamic>> _simulatedReports = [];
  final List<Map<String, String>> _simulatedIDUploads = []; // userId -> path

  bool get isRealSupabase => !_isSimulation && _client != null;

  /// Test-only hook to replace the simulation post table with a known fixture.
  @visibleForTesting
  void debugSeedSimulatedPosts(List<Post> posts) {
    _simulatedPosts = List<Post>.from(posts);
  }


  Future<void> initialize({String? url, String? publishableKey}) async {
    _simulatedUsers =
        mockAccounts.map((acc) => acc['user'] as AppUser).toList();
    _simulatedPosts = List<Post>.from(mockPosts);

    final hasRealCreds = url != null &&
        publishableKey != null &&
        url.isNotEmpty &&
        publishableKey.isNotEmpty;

    if (hasRealCreds) {
      try {
        await Supabase.initialize(
          url: url,
          publishableKey: publishableKey,
        );
        _client = Supabase.instance.client;
        _isSimulation = false;
        debugPrint('Polyticks: Connected to real Supabase instance.');
      } catch (e) {
        _isSimulation = true;
        debugPrint('Polyticks: Failed to connect to real Supabase: $e');
      }
    } else {
      _isSimulation = true;
      try {
        // Initialize with dummy values directly (do NOT check Supabase.instance beforehand)
        await Supabase.initialize(
          url: 'https://placeholder.supabase.co',
          publishableKey: 'placeholder-anon-key-12345',
        );
        _client = Supabase.instance.client;
      } catch (_) {
        // Ignored if already initialized in another test run
      }
      debugPrint('Polyticks: Running in SIMULATION mode (Mock data).');
    }
  }

  // ── AUTHENTICATION ──

  Future<bool> sendOTP(String phoneNumber) async {
    if (isRealSupabase) {
      // Supabase requires strict E.164 format — no spaces or dashes.
      final phone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      try {
        debugPrint('[OTP] sending to $phone ...');
        await _client!.auth
            .signInWithOtp(phone: phone)
            .timeout(const Duration(seconds: 15));
        debugPrint('[OTP] sent OK');
        return true;
      } catch (e) {
        debugPrint('Error sending OTP: $e');
        return false;
      }
    } else {
      debugPrint('Simulating OTP Sent to $phoneNumber');
      return true;
    }
  }

  Future<AppUser?> verifyOTP(String phoneNumber, String otp) async {
    if (isRealSupabase) {
      try {
        debugPrint('[OTP] verifying for $phoneNumber ...');
        final response = await _client!.auth
            .verifyOTP(
          phone: phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), ''),
          token: otp,
          type: OtpType.sms,
        )
            .timeout(const Duration(seconds: 15));
        debugPrint('[OTP] verify OK');
        if (response.user != null) {
          return await fetchProfile(response.user!.id, response.user!.phone);
        }
      } catch (e) {
        debugPrint('Error verifying OTP: $e');
      }
      return null;
    } else {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
      try {
        final existing = _simulatedUsers.firstWhere(
          (u) =>
              u.email.contains(cleanPhone) ||
              u.displayName.contains(cleanPhone),
        );
        return existing;
      } catch (_) {
        final newUser = AppUser(
          id: 'sim_u_${DateTime.now().millisecondsSinceEpoch}',
          displayName: 'Janta Member',
          role: UserRole.janta,
          avatarColor: '#4ECDC4',
          email: '$cleanPhone@janta.in',
        );
        _simulatedUsers.add(newUser);
        return newUser;
      }
    }
  }

  Future<AppUser?> fetchProfile(String userId, String? phone) async {
    if (isRealSupabase) {
      try {
        final data = await _client!
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (data != null) {
          UserRole role = UserRole.janta;
          if (data['role'] == 'verified_user') {
            role = UserRole.partyMember;
          }
          if (data['role'] == 'org_placeholder' || data['role'] == 'admin') {
            role = UserRole.party;
          }

          return AppUser(
            id: userId,
            displayName: data['username'] ?? 'User',
            role: role,
            avatarColor: data['avatar_color'] ?? '#4ECDC4',
            email: phone ?? '',
            verificationStatus: data['verification_status'] as String?,
            // Live gate: drives the post-login ID verification screen.
            isVerified: data['is_verified'] == true,
          );
        }
        // No profile row yet (e.g. test-phone logins or users created before
        // the handle_new_user trigger existed — there is no client-side
        // INSERT policy on profiles, so we cannot seed it from here).
        // Fall back to a local identity anchored to the REAL auth uid so the
        // user can still enter and explore the UI. Backend writes that need
        // a profiles row will be limited until one is seeded by an admin.
        debugPrint(
            'fetchProfile: no profile row for $userId — using local fallback '
            'identity (UI exploration mode).');
        return AppUser(
          id: userId,
          displayName: phone != null ? 'User ${phone.substring(phone.length - 4)}' : 'New User',
          role: UserRole.janta,
          avatarColor: '#4ECDC4',
          email: phone ?? '',
          isVerified: false,
        );
      } catch (e) {
        debugPrint('Error fetching profile: $e');
      }
    }
    return null;
  }

  Future<bool> updateUserCommunity(String userId, String communityId) async {
    if (isRealSupabase) {
      if (!isUuid(communityId)) {
        debugPrint(
            'updateUserCommunity: "$communityId" is not a UUID — skipping DB '
            'write (community entities not yet modelled).');
        return true;
      }
      try {
        await _client!
            .from('profiles')
            .update({'community_id': communityId}).eq('id', userId);
        return true;
      } catch (e) {
        debugPrint('Error updating user community: $e');
        return false;
      }
    } else {
      try {
        final user = _simulatedUsers.firstWhere((u) => u.id == userId);
        user.communityId = communityId;
      } catch (_) {}
      return true;
    }
  }

  Future<bool> deleteMyAccount() async {
    if (isRealSupabase) {
      try {
        await _client!.from('profiles').delete().eq('id', currentUserId!);
        await _client!.auth.signOut();
        return true;
      } catch (e) {
        debugPrint('Error deleting account: $e');
        return false;
      }
    }
    // Simulation
    _simulatedUsers.removeWhere((u) => u.id == currentUserId);
    return true;
  }

  /// Fresh verification status for the signed-in user, read straight from
  /// the DB so admin approvals/rejections show up without re-login.
  /// Returns null in simulation mode (UI falls back to local state).
  Future<String?> getMyVerificationStatus() async {
    if (!isRealSupabase) return null;
    final uid = _client!.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final data = await _client!
          .from('profiles')
          .select('verification_status, is_verified')
          .eq('id', uid)
          .maybeSingle();
      return data?['verification_status'] as String?;
    } catch (e) {
      debugPrint('getMyVerificationStatus error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    if (isRealSupabase) {
      await _client!.auth.signOut();
    }
  }

  // ── FEEDS & POSTS ──

  /// Describes how a dual-feed request maps onto the `posts` table filters,
  /// mirroring the SQL contract exactly:
  /// - Hyper-Local (`hyperLocal=true`, valid `communityId`) -> `community_id == <id>`
  /// - National/Broader -> `community_id IS NULL`
  ///
  /// Exposed for tests so the simulation fallback can never drift from the
  /// real-query semantics (T1.3).
  @visibleForTesting
  static ({String? eqCommunityId, bool communityIdIsNull}) feedFilterSpec(
      {bool hyperLocal = false, String? communityId}) {
    if (hyperLocal && communityId != null) {
      return (eqCommunityId: communityId, communityIdIsNull: false);
    }
    return (eqCommunityId: null, communityIdIsNull: true);
  }

  /// Pure in-memory equivalent of the dual-feed SQL filters above.
  /// Used by the simulation fallback so offline/mock runs behave identically
  /// to the real query (including `created_at DESC` ordering).
  @visibleForTesting
  static List<Post> applyFeedFilter(
    List<Post> posts, {
    bool hyperLocal = false,
    String? communityId,
  }) {
    final spec = feedFilterSpec(hyperLocal: hyperLocal, communityId: communityId);
    final filtered = posts.where((p) {
      if (p.isHidden) return false;
      if (spec.communityIdIsNull) return p.communityId == null;
      return p.communityId == spec.eqCommunityId;
    }).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  Future<List<Post>> getPosts(
      {bool hyperLocal = false, String? communityId}) async {
    if (isRealSupabase) {
      try {
        final filter =
            feedFilterSpec(hyperLocal: hyperLocal, communityId: communityId);
        var query = _client!.from('posts').select().eq('is_hidden', false);
        // Community names from the selector aren't DB UUIDs — a hyper-local
        // filter with an invalid id would crash (22P02). Degrade to the
        // broader feed until communities become real rows.
        final validCommunityId =
            !filter.communityIdIsNull && isUuid(filter.eqCommunityId);
        if (validCommunityId) {
          query = query.eq('community_id', filter.eqCommunityId!);
        } else {
          query = query.isFilter('community_id', null);
        }
        final List data = await query.order('created_at', ascending: false);
        debugPrint(
            'SupabaseService: Fetched ${data.length} posts for hyperLocal=$hyperLocal, communityId=$communityId');
        return data.map((p) {
          return Post(
            id: p['id'],
            partyId: 'p1',
            content: p['content'],
            createdAt: DateTime.parse(p['created_at']),
            likeCount: p['like_count'] ?? 0,
            dislikeCount: p['dislike_count'] ?? 0,
            commentCount: 0,
            type: PostType.standard,
            isHidden: p['is_hidden'] ?? false,
            flaggedReason: p['flagged_reason'],
          );
        }).toList();
      } catch (e) {
        debugPrint('Error loading posts: $e');
        return [];
      }
    } else {
      // Simulation fallback MUST mirror the real-query semantics exactly
      // (same filter spec, same created_at DESC ordering).
      return applyFeedFilter(_simulatedPosts,
          hyperLocal: hyperLocal, communityId: communityId);
    }
  }

  Future<Post?> createPost(
    AppUser author,
    String content, {
    String? mediaPath,
    String? imageEmoji,
    ChannelType channelType = ChannelType.broader,
    String? communityId,
    PostType? type,
  }) async {
    // Run content safety moderation prior to database commit
    final isSafe =
        await AIModerationService.instance.checkContentSafety(content);
    final isHidden = !isSafe;
    final flaggedReason = isHidden ? 'ai_prescreen' : null;

    // Strict Role-Based Representation:
    // - Janta user: No party representation option -> partyId = 'janta'
    // - Party member: Only represents their own registered party -> partyId = author.partyId
    // - Party: Is the party itself -> partyId = author.partyId
    final String targetPartyId;
    if (author.role == UserRole.janta) {
      targetPartyId = 'janta';
    } else {
      targetPartyId = author.partyId ?? 'janta';
    }

    final PostType postType = type ??
        (author.role == UserRole.partyMember
            ? PostType.memberPost
            : PostType.standard);

    if (isRealSupabase) {
      try {
        String? mediaUrl;
        if (mediaPath != null) {
          final file = File(mediaPath);
          final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
          await _client!.storage.from('post-media').upload(filename, file);
          mediaUrl = _client!.storage.from('post-media').getPublicUrl(filename);
        }

        final response = await _client!
            .from('posts')
            .insert({
              'author_id': author.id,
              'content': content,
              'media_url': mediaUrl,
              'is_hidden': isHidden,
              'flagged_reason': flaggedReason,
            })
            .select()
            .single();

        return Post(
          id: response['id'],
          partyId: targetPartyId,
          content: response['content'],
          imageEmoji: imageEmoji,
          createdAt: DateTime.parse(response['created_at']),
          likeCount: 0,
          dislikeCount: 0,
          commentCount: 0,
          type: postType,
          channelType: channelType,
          communityId: communityId ?? author.communityId,
          authorId: author.id,
          isHidden: response['is_hidden'] ?? false,
          flaggedReason: response['flagged_reason'],
        );
      } catch (e) {
        debugPrint('Error creating post: $e');
        return null;
      }
    } else {
      final newPost = Post(
        id: 'sim_post_${DateTime.now().millisecondsSinceEpoch}',
        partyId: targetPartyId,
        content: content,
        imageEmoji: imageEmoji,
        createdAt: DateTime.now(),
        likeCount: 0,
        dislikeCount: 0,
        commentCount: 0,
        type: postType,
        channelType: channelType,
        communityId: communityId ?? author.communityId,
        authorId: author.id,
        isHidden: isHidden,
        flaggedReason: flaggedReason,
      );
      _simulatedPosts.insert(0, newPost);
      mockPosts.insert(0, newPost);
      return newPost;
    }
  }

  // ── VOTING & REACTIONS ──

  Future<void> reactToPost(
      String userId, String postId, InteractionType reactionType) async {
    if (isRealSupabase) {
      try {
        if (reactionType == InteractionType.none) {
          await _client!.from('reactions').delete().match({
            'user_id': userId,
            'post_id': postId,
          });
        } else {
          final typeStr =
              reactionType == InteractionType.like ? 'like' : 'dislike';
          await _client!.from('reactions').upsert({
            'user_id': userId,
            'post_id': postId,
            'type': typeStr,
          });
        }
      } catch (e) {
        debugPrint('Error casting reaction: $e');
      }
    } else {
      _simulatedReactions
          .removeWhere((r) => r['userId'] == userId && r['postId'] == postId);
      if (reactionType != InteractionType.none) {
        _simulatedReactions.add({
          'userId': userId,
          'postId': postId,
          'type': reactionType,
        });
      }
      final post = _simulatedPosts.firstWhere((p) => p.id == postId);
      post.interaction = reactionType;
    }
  }

  // ── MODERATION & SAFETY ──

  Future<void> reportPost(
      String reporterId, String postId, String reason) async {
    if (isRealSupabase) {
      try {
        await _client!.from('reports').insert({
          'reporter_id': reporterId,
          'post_id': postId,
          'reason': reason,
        });
      } catch (e) {
        debugPrint('Error reporting post: $e');
      }
    } else {
      _simulatedReports.add({
        'reporterId': reporterId,
        'postId': postId,
        'reason': reason,
        'createdAt': DateTime.now(),
      });
      debugPrint('Post $postId reported for: $reason');
    }
  }

  // ── ID VERIFICATION & PURGING ──

  Future<void> uploadIDVerification(String userId, String imagePath,
      {Uint8List? webBytes}) async {
    // V4.0: manual document upload is the WEB-ONLY fallback *once* DigiLocker
    // is live (credentials configured). While DigiLocker is deferred (v6),
    // mobile keeps manual upload as its only path. Simulation mode always
    // available for tests/offline dev.
    if (isRealSupabase && !kIsWeb && AppConfig.isDigilockerEnabled) {
      throw UnsupportedError(
          'Manual ID upload is restricted to the web client while instant '
          'DigiLocker verification is enabled. Use DigiLockerVerificationService.');
    }
    if (isRealSupabase) {
      try {
        // The storage RLS policies compare the first path segment against
        // auth.uid() from the request JWT, so the folder MUST come from the
        // authenticated session — never from the AppUser model, which can be
        // a mock/demo identity ('u3') when logged in via demo personas.
        final authUid = _client!.auth.currentUser?.id;
        debugPrint('[IDUpload] auth.uid=$authUid');
        if (authUid == null) {
          throw StateError(
              'Not signed in to Supabase — ID upload requires an authenticated '
              'session. Demo-persona logins are simulation-only; please log '
              'in with your phone number (OTP).');
        }
        // Per-user folder: lets one storage policy scope each user to their
        // own prefix ((storage.foldername(name))[1] = auth.uid()).
        final filename = '$authUid/id_verification.jpg';
        if (kIsWeb && webBytes != null) {
          // Web: no dart:io — upload raw bytes instead of a File.
          await _client!.storage.from('id-verifications').uploadBinary(
                filename,
                webBytes,
                fileOptions:
                    const FileOptions(cacheControl: '3600', upsert: true),
              );
        } else {
          final file = File(imagePath);
          await _client!.storage.from('id-verifications').upload(
                filename,
                file,
                fileOptions:
                    const FileOptions(cacheControl: '3600', upsert: true),
              );
        }
        await _client!
            .from('profiles')
            .update({'verification_status': 'pending'}).eq('id', authUid);
      } catch (e) {
        debugPrint('Error uploading verification ID: $e');
        // Surface to the caller: without this, the UI would show "pending"
        // even though neither the file nor the status update landed.
        rethrow;
      }
    } else {
      _simulatedIDUploads.removeWhere((u) => u['userId'] == userId);
      _simulatedIDUploads.add({'userId': userId, 'path': imagePath});
      final user = _simulatedUsers.firstWhere((u) => u.id == userId);
      user.isAnonymous = false;
      debugPrint('Simulated ID Uploaded for $userId. Image path: $imagePath');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    if (isRealSupabase) {
      try {
        final List data = await _client!
            .from('profiles')
            .select('id, username, phone_number')
            .eq('verification_status', 'pending');
        return Future.wait(data.map((u) async {
          final filename = '${u['id']}/id_verification.jpg';
          // Private bucket: public URLs would 403 — use a time-limited
          // signed URL (1 hour) for the admin review preview.
          final imageUrl = await _client!.storage
              .from('id-verifications')
              .createSignedUrl(filename, 3600);
          return {
            'id': u['id'],
            'username': u['username'] ?? 'User',
            'phone': u['phone_number'] ?? '',
            'imageUrl': imageUrl,
          };
        }));
      } catch (e) {
        debugPrint('Error fetching verifications: $e');
        return [];
      }
    } else {
      final List<Map<String, dynamic>> pending = [];
      for (final upload in _simulatedIDUploads) {
        final userId = upload['userId']!;
        try {
          final user = _simulatedUsers.firstWhere((u) => u.id == userId);
          pending.add({
            'id': user.id,
            'username': user.displayName,
            'phone': user.email,
            'imageUrl': upload['path']!,
          });
        } catch (_) {}
      }
      return pending;
    }
  }

  Future<void> approveVerification(String userId) async {
    if (isRealSupabase) {
      try {
        await _client!.from('profiles').update({
          'is_verified': true,
          'verification_status': 'approved',
          'role': 'verified_user'
        }).eq('id', userId);
        final filename = '$userId/id_verification.jpg';
        await _client!.storage.from('id-verifications').remove([filename]);
        debugPrint(
            'Verification approved and ID image purged successfully for $userId.');
      } catch (e) {
        debugPrint('Error approving verification: $e');
      }
    } else {
      try {
        final user = _simulatedUsers.firstWhere((u) => u.id == userId);
        final index = _simulatedUsers.indexOf(user);
        _simulatedUsers[index] = AppUser(
          id: user.id,
          displayName: '${user.displayName} (Verified)',
          role: UserRole.partyMember,
          avatarColor: user.avatarColor,
          email: user.email,
          isAnonymous: false,
        );
        _simulatedIDUploads.removeWhere((u) => u['userId'] == userId);
        debugPrint('Simulated Approval & ID Document purged for $userId.');
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
  }

  Future<void> rejectVerification(String userId) async {
    if (isRealSupabase) {
      try {
        await _client!
            .from('profiles')
            .update({'verification_status': 'rejected'}).eq('id', userId);
        final filename = '$userId/id_verification.jpg';
        await _client!.storage.from('id-verifications').remove([filename]);
        debugPrint(
            'Verification rejected and ID image purged successfully for $userId.');
      } catch (e) {
        debugPrint('Error rejecting verification: $e');
      }
    } else {
      _simulatedIDUploads.removeWhere((u) => u['userId'] == userId);
      debugPrint('Simulated Rejection & ID Document purged for $userId.');
    }
  }

  Future<void> voteOnPoll(String pollId, String optionId) async {
    if (isRealSupabase) {
      try {
        await _client!.from('poll_votes').insert({
          'poll_id': pollId,
          'option_id': optionId,
          'user_id': _client!.auth.currentUser!.id,
        });
        debugPrint('Vote cast for $optionId in poll $pollId.');
      } catch (e) {
        debugPrint('Error casting vote: $e');
        rethrow;
      }
    } else {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('Simulated vote cast for $optionId in poll $pollId.');
    }
  }

  // ── OPTIMISTIC POLL VOTING (V3 Task 3.3 / Phase 2) ──

  /// Exact SnackBar text required by the spec when a vote fails
  /// (double vote / RLS denial).
  static const String pollVoteFailureMessage =
      'Action failed: Ensure you are a verified community member';

  /// Last poll-vote failure message (null when the last vote succeeded).
  /// The UI layer surfaces this in a SnackBar.
  String? lastPollVoteError;

  /// Simulation-mode poll registry mirroring `polls` + `poll_options`.
  /// `communityId` is the community_id of the poll's parent post
  /// (null = national poll, votable by ANY verified member).
  final List<({Poll poll, String? communityId})> _simulatedPolls = [];

  /// Simulation-mode `poll_votes` rows (mirrors UNIQUE(poll_id, voter_id)).
  final List<Map<String, String>> _simulatedPollVotes = [];

  /// Test-only voter directory so sim-mode RLS checks (is_verified,
  /// community membership) are deterministic without touching mock data.
  List<AppUser>? _simulatedPollUsers;

  @visibleForTesting
  void debugSeedSimulatedPolls(
    List<({Poll poll, String? communityId})> polls, {
    List<AppUser>? users,
  }) {
    _simulatedPolls
      ..clear()
      ..addAll(polls);
    _simulatedPollVotes.clear();
    _simulatedPollUsers = users;
    lastPollVoteError = null;
  }

  /// Percentage of total votes held by one option.
  /// Zero-total guard: returns 0% instead of dividing by zero (T2.5).
  @visibleForTesting
  static double pollOptionPercent(
      {required int voteCount, required int totalVotes}) {
    if (totalVotes <= 0) return 0;
    return (voteCount / totalVotes) * 100;
  }

  AppUser? _findSimPollUser(String userId) {
    final users = _simulatedPollUsers;
    if (users == null) return null;
    for (final u in users) {
      if (u.id == userId) return u;
    }
    return null;
  }

  /// Optimistic poll voting (mirrors the DB contract exactly):
  /// 1. IMMEDIATELY (synchronously, before any await) increments the chosen
  ///    option's voteCount and sets votedOptionId -> UI switches to Results
  ///    Mode.
  /// 2. Persists to `poll_votes` (real Supabase) or validates against the
  ///    mirrored contract in simulation:
  ///    - UNIQUE(poll_id, voter_id) -> double vote
  ///    - RLS "Verified community members can vote" -> unverified voters and
  ///      verified members of a DIFFERENT community are denied.
  /// 3. On ANY failure: reverts ALL local counts to their pre-vote values,
  ///    restores the previous votedOptionId, records
  ///    [pollVoteFailureMessage] in [lastPollVoteError] (UI shows the
  ///    SnackBar) and returns false.
  Future<bool> voteInPoll(
      String userId, String pollId, String optionId) async {
    lastPollVoteError = null;

    ({Poll poll, String? communityId})? entry;
    for (final e in _simulatedPolls) {
      if (e.poll.id == pollId) {
        entry = e;
        break;
      }
    }
    if (entry == null) {
      lastPollVoteError = pollVoteFailureMessage;
      return false;
    }
    final poll = entry.poll;

    PollOption? option;
    for (final o in poll.options) {
      if (o.id == optionId) {
        option = o;
        break;
      }
    }
    if (option == null) {
      lastPollVoteError = pollVoteFailureMessage;
      return false;
    }

    // Pre-vote snapshot for a FULL revert.
    final preVotes = poll.options.map((o) => o.votes).toList();
    final preVotedOptionId = poll.votedOptionId;

    // ── 1. OPTIMISTIC local update (before any await) ──
    option.votes += 1;
    poll.votedOptionId = optionId;

    // ── 2. Persist / validate ──
    try {
      if (isRealSupabase) {
        await _client!.from('poll_votes').insert({
          'poll_id': pollId,
          'option_id': optionId,
          'voter_id': userId,
        });
      } else {
        // Simulated network latency.
        await Future.delayed(const Duration(milliseconds: 50));

        // UNIQUE(poll_id, voter_id)
        final duplicate = _simulatedPollVotes
            .any((v) => v['pollId'] == pollId && v['voterId'] == userId);

        // RLS: voter must be verified...
        final user = _findSimPollUser(userId);
        final verified = user != null && user.isVerified;
        // ...and belong to the poll's community (national polls accept any
        // verified member).
        final sameCommunity = entry.communityId == null ||
            (user?.communityId == entry.communityId);

        if (duplicate || !verified || !sameCommunity) {
          return _revertPollVote(poll, preVotes, preVotedOptionId);
        }
        _simulatedPollVotes.add({'pollId': pollId, 'voterId': userId});
      }
      return true;
    } catch (e) {
      debugPrint('Error casting poll vote: $e');
      return _revertPollVote(poll, preVotes, preVotedOptionId);
    }
  }

  bool _revertPollVote(
      Poll poll, List<int> preVotes, String? preVotedOptionId) {
    for (var i = 0; i < poll.options.length; i++) {
      poll.options[i].votes = preVotes[i];
    }
    poll.votedOptionId = preVotedOptionId;
    lastPollVoteError = pollVoteFailureMessage;
    return false;
  }
}
