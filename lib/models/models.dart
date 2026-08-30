// ─────────────────────────────────────────────
//  Polyticks – Data Models
// ─────────────────────────────────────────────

enum UserRole { janta, party, partyMember, admin }

/// Hierarchy tier roles a Party can assign to members.
/// Lower tier number = higher authority.
enum PartyRole {
  president,
  vicePresident,
  execCommittee,
  generalSecretary,
  treasurer,
  statePresident,
  districtPresident,
  mandalOfficer,
  groundWorker;
}

extension PartyRoleX on PartyRole {
  int get tier {
    switch (this) {
      case PartyRole.president: return 1;
      case PartyRole.vicePresident: return 2;
      case PartyRole.execCommittee: return 3;
      case PartyRole.generalSecretary: return 4;
      case PartyRole.treasurer: return 5;
      case PartyRole.statePresident: return 6;
      case PartyRole.districtPresident: return 7;
      case PartyRole.mandalOfficer: return 8;
      case PartyRole.groundWorker: return 9;
    }
  }

  String get label {
    switch (this) {
      case PartyRole.president: return 'President';
      case PartyRole.vicePresident: return 'Vice President';
      case PartyRole.execCommittee: return 'Executive Committee';
      case PartyRole.generalSecretary: return 'General Secretary';
      case PartyRole.treasurer: return 'Treasurer';
      case PartyRole.statePresident: return 'State President';
      case PartyRole.districtPresident: return 'District President';
      case PartyRole.mandalOfficer: return 'Mandal Level Officer';
      case PartyRole.groundWorker: return 'Ground Worker';
    }
  }

  /// Top-tier roles assignable ONLY by the Party Official account.
  bool get isTopTier =>
      this == PartyRole.president ||
      this == PartyRole.vicePresident ||
      this == PartyRole.execCommittee ||
      this == PartyRole.generalSecretary ||
      this == PartyRole.treasurer;
}

class AppUser {
  final String id;
  final String displayName;
  UserRole role; // mutable – accounts are promoted janta → partyMember on approval (#8)
  String? partyId;             // partyMember only – which party they belong to
  PartyRole? partyRole;        // partyMember only – hierarchy tier within their party
  final String avatarColor;    // fallback color when no photo
  String? avatarUrl;           // profile picture path (local/network)
  final String email;
  final String? phone;
  String? communityId;
  final bool isVerified;
  bool isAnonymous;            // For Janta users to hide their name
  bool isGuest;                // Synthetic guest user

  /// Live ID-verification state mirroring profiles.verification_status:
  /// 'unverified' | 'pending' | 'approved' | 'rejected'. Null in older
  /// fixtures; the verification status screen treats null as 'unverified'.
  String? verificationStatus;

  AppUser({
    required this.id,
    required this.displayName,
    required this.role,
    this.partyId,
    this.partyRole,
    required this.avatarColor,
    this.avatarUrl,
    required this.email,
    this.phone,
    this.communityId,
    this.verificationStatus,
    this.isVerified = true,
    this.isAnonymous = false,
    this.isGuest = false,
  });

  /// Display name shown to OTHER users based on viewer's role
  String visibleName(UserRole viewerRole) {
    // Janta users can choose to be anonymous
    if (role == UserRole.janta && isAnonymous) {
      if (viewerRole == UserRole.party || viewerRole == UserRole.partyMember) {
        return 'Janta';
      }
    }
    return displayName;
  }

  String get roleLabel {
    switch (role) {
      case UserRole.janta:
        return 'Janta';
      case UserRole.party:
        return 'Party';
      case UserRole.partyMember:
        return 'Party Member';
      case UserRole.admin:
        return 'Admin Moderator';
    }
  }
}

class Party {
  final String id;
  final String name;
  final String shortName;
  final String description;
  final String logoEmoji;
  final String bannerColor;
  final int followerCount;
  final int memberCount;

  const Party({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.logoEmoji,
    required this.bannerColor,
    required this.followerCount,
    required this.memberCount,
  });
}

enum PostType { standard, memberTagged, memberPost, update }
enum InteractionType { none, like, dislike }
enum ChannelType { hyperLocal, broader }

/// Status of fact checking on a post matching PostgreSQL ENUM `public.fact_check_status`.
enum FactCheckStatus {
  none,
  underReview,
  verifiedContext,
  disputed,
  autoHidden;

  static FactCheckStatus fromString(String value) {
    switch (value) {
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

  String toDbValue() {
    switch (this) {
      case FactCheckStatus.none:
        return 'none';
      case FactCheckStatus.underReview:
        return 'under_review';
      case FactCheckStatus.verifiedContext:
        return 'verified_context';
      case FactCheckStatus.disputed:
        return 'disputed';
      case FactCheckStatus.autoHidden:
        return 'auto_hidden';
    }
  }
}

/// Type of fact-check vote.
enum FactCheckVoteType {
  upvote,
  downvote;

  static FactCheckVoteType fromString(String value) {
    return value == 'upvote' ? FactCheckVoteType.upvote : FactCheckVoteType.downvote;
  }

  String toDbValue() => this == FactCheckVoteType.upvote ? 'upvote' : 'downvote';
}

/// Submission lifecycle state for context notes.
enum FactCheckSubmissionStatus {
  idle,
  submitting,
  success,
  error;
}

/// Urgency level for moderation queue SLA countdowns.
enum SlaUrgency {
  normal,      // > 12 hours remaining
  warning,     // 4 to 12 hours remaining
  critical,    // 0 to 4 hours remaining
  breached;    // SLA expired (< 0 seconds)
}

/// Immutable fact-check note entity attached to a post.
class FactCheckItem {
  final String id;
  final String postId;
  final String authorId;
  final String? authorUsername;
  final bool authorIsVerified;
  final String contextNote;
  final List<String> sourceLinks;
  final int upvotes;
  final int downvotes;
  final FactCheckVoteType? userVote;
  final DateTime createdAt;

  const FactCheckItem({
    required this.id,
    required this.postId,
    required this.authorId,
    this.authorUsername,
    this.authorIsVerified = false,
    required this.contextNote,
    this.sourceLinks = const [],
    this.upvotes = 0,
    this.downvotes = 0,
    this.userVote,
    required this.createdAt,
  });

  int get netScore => upvotes - downvotes;

  FactCheckItem copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorUsername,
    bool? authorIsVerified,
    String? contextNote,
    List<String>? sourceLinks,
    int? upvotes,
    int? downvotes,
    FactCheckVoteType? Function()? userVote,
    DateTime? createdAt,
  }) {
    return FactCheckItem(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorIsVerified: authorIsVerified ?? this.authorIsVerified,
      contextNote: contextNote ?? this.contextNote,
      sourceLinks: sourceLinks ?? this.sourceLinks,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      userVote: userVote != null ? userVote() : this.userVote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FactCheckItem.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    FactCheckVoteType? currentUserVote;
    if (json['fact_check_votes'] != null && (json['fact_check_votes'] as List).isNotEmpty) {
      final voteList = json['fact_check_votes'] as List;
      final match = voteList.firstWhere(
        (v) => v['voter_id'] == currentUserId,
        orElse: () => null,
      );
      if (match != null) {
        currentUserVote = FactCheckVoteType.fromString(match['vote_type'] as String);
      }
    }

    final authorProfile = json['profiles'] as Map<String, dynamic>?;

    return FactCheckItem(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      authorUsername: authorProfile?['username'] as String?,
      authorIsVerified: authorProfile?['is_verified'] as bool? ?? false,
      contextNote: json['context_note'] as String,
      sourceLinks: (json['source_links'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      userVote: currentUserVote,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Moderation queue item representing reported content under review.
class ModerationQueueItem {
  final String reportId;
  final String postId;
  final String postContent;
  final String? postMediaUrl;
  final String authorId;
  final String? authorUsername;
  final String reporterId;
  final String reason;
  final int totalReportsOnPost;
  final int likeCount;
  final int dislikeCount;
  final FactCheckStatus factCheckStatus;
  final bool isHidden;
  final DateTime firstReportedAt;
  final DateTime slaDeadline;

  const ModerationQueueItem({
    required this.reportId,
    required this.postId,
    required this.postContent,
    this.postMediaUrl,
    required this.authorId,
    this.authorUsername,
    required this.reporterId,
    required this.reason,
    required this.totalReportsOnPost,
    required this.likeCount,
    required this.dislikeCount,
    required this.factCheckStatus,
    required this.isHidden,
    required this.firstReportedAt,
    required this.slaDeadline,
  });

  Duration get remainingSla => slaDeadline.difference(DateTime.now());

  SlaUrgency get slaUrgency {
    final diff = remainingSla;
    if (diff.isNegative) return SlaUrgency.breached;
    if (diff.inHours < 4) return SlaUrgency.critical;
    if (diff.inHours < 12) return SlaUrgency.warning;
    return SlaUrgency.normal;
  }
}

/// Filter criteria for the Admin Moderation Dashboard.
class ModerationFilter {
  final SlaUrgency? urgencyFilter;
  final FactCheckStatus? statusFilter;
  final bool showOnlyPending;
  final String? searchQuery;

  const ModerationFilter({
    this.urgencyFilter,
    this.statusFilter,
    this.showOnlyPending = true,
    this.searchQuery,
  });

  ModerationFilter copyWith({
    SlaUrgency? Function()? urgencyFilter,
    FactCheckStatus? Function()? statusFilter,
    bool? showOnlyPending,
    String? Function()? searchQuery,
  }) {
    return ModerationFilter(
      urgencyFilter: urgencyFilter != null ? urgencyFilter() : this.urgencyFilter,
      statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      showOnlyPending: showOnlyPending ?? this.showOnlyPending,
      searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
    );
  }
}

class Post {
  final String id;
  final String partyId;
  String content;
  final String? imageEmoji;   // mock "image" via big emoji
  final DateTime createdAt;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final PostType type;
  final ChannelType channelType;
  final String? communityId; // For hyper-local posts
  InteractionType interaction;
  final List<String> editHistory;
  final String? authorId; // For member posts
  bool isHidden;
  String? flaggedReason;
  FactCheckStatus factCheckStatus;
  String? factCheckContext;
  List<String> factCheckSources;

  Post({
    required this.id,
    required this.partyId,
    required this.content,
    this.imageEmoji,
    required this.createdAt,
    required this.likeCount,
    this.dislikeCount = 0,
    required this.commentCount,
    required this.type,
    this.channelType = ChannelType.broader,
    this.communityId,
    this.interaction = InteractionType.none,
    this.editHistory = const [],
    this.authorId,
    this.isHidden = false,
    this.flaggedReason,
    this.factCheckStatus = FactCheckStatus.none,
    this.factCheckContext,
    this.factCheckSources = const [],
  });
}

class Comment {
  final String id;
  final String postId;
  final String? parentId;      // reply target – flat storage, unlimited depth
  final String authorId;
  final String content;
  final DateTime createdAt;
  int likeCount;
  int dislikeCount;
  InteractionType userInteraction;

  Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.userInteraction = InteractionType.none,
  });
}

/// A Janta member's request to join a party (#7).
class JoinRequest {
  final String id;
  final String userId;
  final String username;
  final String partyId;
  String status; // pending | approved | rejected
  final DateTime createdAt;

  JoinRequest({
    required this.id,
    required this.userId,
    required this.username,
    required this.partyId,
    this.status = 'pending',
    required this.createdAt,
  });
}

class PollOption {
  final String id;
  final String text;
  int votes;

  PollOption({required this.id, required this.text, required this.votes});
}

class Poll {
  final String id;
  final String partyId;
  final String question;
  final List<PollOption> options;
  final DateTime endsAt;
  String? votedOptionId;

  Poll({
    required this.id,
    required this.partyId,
    required this.question,
    required this.options,
    required this.endsAt,
    this.votedOptionId,
  });

  int get totalVotes => options.fold(0, (sum, o) => sum + o.votes);
}
