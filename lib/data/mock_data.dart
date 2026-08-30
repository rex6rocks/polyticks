// ─────────────────────────────────────────────
//  Polyticks – Mock Data
// ─────────────────────────────────────────────
import '../models/models.dart';

// ── Parties ──────────────────────────────────
final List<Party> mockParties = [
  const Party(
    id: 'p1',
    name: 'Aam Aadmi Dal',
    shortName: 'AAD',
    description: 'For the common people, by the common people.',
    logoEmoji: '🪔',
    bannerColor: '#FF6B00',
    followerCount: 142300,
    memberCount: 8740,
  ),
  const Party(
    id: 'p2',
    name: 'Bharatiya Rashtriya Morcha',
    shortName: 'BRM',
    description: 'Proud, progressive and united India.',
    logoEmoji: '🦁',
    bannerColor: '#0A5C36',
    followerCount: 289100,
    memberCount: 15620,
  ),
  const Party(
    id: 'p3',
    name: 'Janshakti Party',
    shortName: 'JSP',
    description: 'Empowering every citizen with voice and vote.',
    logoEmoji: '✊',
    bannerColor: '#1565C0',
    followerCount: 98750,
    memberCount: 4320,
  ),
];

// ── Mock Users ────────────────────────────────
// These are the pre-seeded "mockup" login accounts.
// Passwords are plain-text only for demo purposes.
final List<Map<String, dynamic>> mockAccounts = [
  // Janta accounts
  {
    'email': 'arjun@janta.in',
    'password': 'janta123',
    'user': AppUser(
      id: 'u1',
      displayName: 'Arjun Sharma',
      role: UserRole.janta,
      avatarColor: '#4ECDC4',
      email: 'arjun@janta.in',
      phone: '+91 98765 43210',
      communityId: 'Indiranagar Ward #84',
      isVerified: true,
      verificationStatus: 'approved',
      isAnonymous: false,
    ),
  },
  {
    'email': 'priya@janta.in',
    'password': 'janta123',
    'user': AppUser(
      id: 'u2',
      displayName: 'Priya Menon',
      role: UserRole.janta,
      avatarColor: '#A29BFE',
      email: 'priya@janta.in',
      phone: '+91 98765 43211',
      communityId: 'Koramangala 4th Block',
      isVerified: true,
      verificationStatus: 'approved',
      isAnonymous: true,
    ),
  },
  {
    'email': 'ravi@janta.in',
    'password': 'janta123',
    'user': AppUser(
      id: 'u3',
      displayName: 'Ravi Kumar',
      role: UserRole.janta,
      avatarColor: '#FD79A8',
      email: 'ravi@janta.in',
      phone: '+91 98765 43212',
      communityId: 'Whitefield RWA',
      isVerified: false,
      verificationStatus: 'unverified',
      isAnonymous: false,
    ),
  },
  // Party Official accounts
  {
    'email': 'aad@party.in',
    'password': 'party123',
    'user': AppUser(
      id: 'p_u1',
      displayName: 'Aam Aadmi Dal Official',
      role: UserRole.party,
      partyId: 'p1',
      avatarColor: '#FF6B00',
      email: 'aad@party.in',
      phone: '+91 98765 00001',
      isVerified: true,
      verificationStatus: 'approved',
      isAnonymous: false,
    ),
  },
  {
    'email': 'brm@party.in',
    'password': 'party123',
    'user': AppUser(
      id: 'p_u2',
      displayName: 'Bharatiya Rashtriya Morcha Official',
      role: UserRole.party,
      partyId: 'p2',
      avatarColor: '#00B894',
      email: 'brm@party.in',
      phone: '+91 98765 00002',
      isVerified: true,
      verificationStatus: 'approved',
      isAnonymous: false,
    ),
  },
  {
    'email': 'jsp@party.in',
    'password': 'party123',
    'user': AppUser(
      id: 'p_u3',
      displayName: 'Janshakti Party Official',
      role: UserRole.party,
      partyId: 'p3',
      avatarColor: '#0984E3',
      email: 'jsp@party.in',
      phone: '+91 98765 00003',
      isVerified: true,
      verificationStatus: 'approved',
      isAnonymous: false,
    ),
  },
  // Party Member accounts
  {
    'email': 'sneha@member.in',
    'password': 'member123',
    'user': AppUser(
      id: 'm1',
      displayName: 'Sneha Patel',
      role: UserRole.partyMember,
      partyId: 'p1',
      avatarColor: '#FDCB6E',
      email: 'sneha@member.in',
      phone: '+91 98765 11111',
      communityId: 'Indiranagar Ward #84',
      isVerified: true,
      verificationStatus: 'approved',
      isAnonymous: false,
    ),
  },
  {
    'email': 'vikram@member.in',
    'password': 'member123',
    'user': AppUser(
      id: 'm2',
      displayName: 'Vikram Singh',
      role: UserRole.partyMember,
      partyId: 'p2',
      avatarColor: '#6C5CE7',
      email: 'vikram@member.in',
      phone: '+91 98765 22222',
      communityId: 'Connaught Place Ward',
      isVerified: true,
      verificationStatus: 'approved',
      isAnonymous: false,
    ),
  },
  {
    'email': 'nandini@member.in',
    'password': 'member123',
    'user': AppUser(
      id: 'm3',
      displayName: 'Nandini Rao',
      role: UserRole.partyMember,
      partyId: 'p3',
      avatarColor: '#E17055',
      email: 'nandini@member.in',
      phone: '+91 98765 33333',
      communityId: 'Bandra West Ward #5',
      isVerified: true,
      verificationStatus: 'approved',
      isAnonymous: false,
    ),
  },
  // Admin account
  {
    'email': 'admin@polyticks.gov',
    'password': 'admin',
    'user': AppUser(
      id: 'admin_1',
      displayName: 'Admin Officer',
      role: UserRole.admin,
      avatarColor: '#10B981',
      email: 'admin@polyticks.gov',
      phone: '+91 98765 99999',
      isVerified: true,
      verificationStatus: 'approved',
      isAnonymous: false,
    ),
  },
];

// ── Posts ─────────────────────────────────────
final List<Post> mockPosts = [
  Post(
    id: 'post1',
    partyId: 'p1',
    content:
        'Today we launch our Jan Suraksha Yojana – every family in India deserves basic healthcare and education without compromise. 🪔 Share and spread the word!',
    imageEmoji: '🏥',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    likeCount: 4821,
    commentCount: 312,
    type: PostType.standard,
  ),
  Post(
    id: 'post2',
    partyId: 'p2',
    content:
        'Our manifesto on national security is ready. India\'s borders are sacred and we shall protect them at all costs. 🦁 Read the full document at our website.',
    imageEmoji: '🛡️',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    likeCount: 9210,
    commentCount: 584,
    type: PostType.standard,
  ),
  Post(
    id: 'post3',
    partyId: 'p1',
    content:
        '📣 Dear AAD Members – we need YOUR voice! What issues matter most in your constituency? This is a members-only discussion. Tell us below! ⬇️',
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    likeCount: 1023,
    commentCount: 890,
    type: PostType.memberTagged,
  ),
  Post(
    id: 'post4',
    partyId: 'p3',
    content:
        'Janshakti Party calls for complete transparency in electoral bonds. The people have a right to know who funds political parties. #DemocracyFirst ✊',
    imageEmoji: '📜',
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    likeCount: 3450,
    commentCount: 267,
    type: PostType.standard,
  ),
  Post(
    id: 'post5',
    partyId: 'p2',
    content:
        'BRM Youth Wing rally in Delhi tomorrow! 10 AM at Ramlila Maidan. Bring your enthusiasm and your voice. India first, always! 🇮🇳',
    imageEmoji: '🎉',
    createdAt: DateTime.now().subtract(const Duration(hours: 20)),
    likeCount: 6780,
    commentCount: 423,
    type: PostType.standard,
  ),
  Post(
    id: 'post6',
    partyId: 'p3',
    content:
        '✊ JSP Members Only – Upcoming strategy session for the municipal elections. Your input is critical. Please respond with your availability below.',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    likeCount: 512,
    commentCount: 178,
    type: PostType.memberTagged,
  ),
  Post(
    id: 'post7',
    partyId: 'p2',
    content:
        '📣 BRM Members – we are gathering feedback on our new agricultural policy. Your experience on the ground matters most to us. Comment below!',
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
    likeCount: 890,
    commentCount: 340,
    type: PostType.memberTagged,
  ),
  Post(
    id: 'post8',
    partyId: 'p1',
    content:
        'We congratulate our municipal councillors on their win in the Pune by-elections! This is the people\'s victory. Aam Aadmi Dal zindabad! 🎊',
    imageEmoji: '🏆',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    likeCount: 12400,
    commentCount: 1023,
    type: PostType.standard,
  ),
  Post(
    id: 'post9',
    partyId: 'p1',
    content: 'Just finished a ground meeting with local vendors. Our policies are taking shape perfectly!',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    likeCount: 45,
    commentCount: 12,
    type: PostType.memberPost,
    authorId: 'm1',
  ),
];

// ── Comments ──────────────────────────────────
final List<Comment> mockComments = [
  Comment(
    id: 'c1',
    postId: 'post1',
    authorId: 'u1',
    content: 'This is exactly what we needed! Healthcare for all 🙌',
    createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
  ),
  Comment(
    id: 'c2',
    postId: 'post1',
    authorId: 'u2',
    content: 'Finally a party that cares about the common man!',
    createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
  ),
  Comment(
    id: 'c3',
    postId: 'post1',
    authorId: 'u3',
    content: 'How will this be funded? Need more details.',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  Comment(
    id: 'c4',
    postId: 'post3',
    authorId: 'm1',
    content: 'Water scarcity in our area is the biggest concern right now.',
    createdAt: DateTime.now().subtract(const Duration(hours: 7)),
  ),
  Comment(
    id: 'c5',
    postId: 'post3',
    authorId: 'm1',
    content: 'Road infrastructure in tier-2 cities needs urgent attention.',
    createdAt: DateTime.now().subtract(const Duration(hours: 6, minutes: 30)),
  ),
  Comment(
    id: 'c6',
    postId: 'post2',
    authorId: 'u1',
    content: 'Strong stance! But what about internal security?',
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
  ),
  Comment(
    id: 'c7',
    postId: 'post4',
    authorId: 'u2',
    content: 'Transparency is the need of the hour. Fully support this!',
    createdAt: DateTime.now().subtract(const Duration(hours: 11)),
  ),
];

// ── Polls ─────────────────────────────────────
final List<Poll> mockPolls = [
  Poll(
    id: 'poll1',
    partyId: 'p1',
    question: 'Which issue should AAD prioritise in the next parliament session?',
    options: [
      PollOption(id: 'o1', text: 'Healthcare Reform', votes: 3241),
      PollOption(id: 'o2', text: 'Education Policy', votes: 2890),
      PollOption(id: 'o3', text: 'Unemployment', votes: 4120),
      PollOption(id: 'o4', text: 'Farmer Welfare', votes: 1780),
    ],
    endsAt: DateTime.now().add(const Duration(days: 3)),
  ),
  Poll(
    id: 'poll2',
    partyId: 'p2',
    question: 'What should BRM\'s primary focus be for the next state election?',
    options: [
      PollOption(id: 'o5', text: 'National Security', votes: 5670),
      PollOption(id: 'o6', text: 'Economic Growth', votes: 4890),
      PollOption(id: 'o7', text: 'Infrastructure', votes: 3210),
    ],
    endsAt: DateTime.now().add(const Duration(days: 5)),
  ),
  Poll(
    id: 'poll3',
    partyId: 'p3',
    question: 'How should JSP approach electoral reform?',
    options: [
      PollOption(id: 'o8', text: 'Mandatory voting', votes: 1230),
      PollOption(id: 'o9', text: 'Online voting system', votes: 2340),
      PollOption(id: 'o10', text: 'Electoral bond ban', votes: 3450),
      PollOption(id: 'o11', text: 'Lower voting age to 16', votes: 890),
    ],
    endsAt: DateTime.now().add(const Duration(days: 2)),
  ),
];

// ── Followers (partyId → list of user IDs) ────
final Map<String, List<String>> mockFollowers = {
  'p1': ['u1', 'u3'],
  'p2': ['u2'],
  'p3': ['u1', 'u2', 'u3'],
};

// ── Member followers (memberUserId → follower userIds) (#5) ──
final Map<String, List<String>> mockMemberFollowers = {
  'm1': ['u2', 'u3'],
  'm2': ['u1'],
};
bool isFollowingMember(String memberId, String userId) =>
    (mockMemberFollowers[memberId] ?? []).contains(userId);

/// Toggle a user's follow of a party member. Returns true if now following.
/// Self-follows are rejected (#2): returns current state unchanged.
bool toggleMemberFollow(String memberId, String userId) {
  if (memberId == userId) return isFollowingMember(memberId, userId);
  final list = mockMemberFollowers.putIfAbsent(memberId, () => []);
  if (list.contains(userId)) {
    list.remove(userId);
    return false;
  }
  list.add(userId);
  return true;
}

// ── Party join requests (#7) ──────────────────
final List<JoinRequest> mockJoinRequests = [];

// ── Helper: find party by id ──────────────────
Party? partyById(String id) {
  return mockParties.cast<Party?>().firstWhere((p) => p?.id == id, orElse: () => null);
}

// ── Helper: get comments for a post ──────────
List<Comment> commentsForPost(String postId) =>
    mockComments.where((c) => c.postId == postId).toList();

// ── Helper: get user by id ────────────────────
AppUser? userById(String id) {
  for (final acc in mockAccounts) {
    if ((acc['user'] as AppUser).id == id) return acc['user'] as AppUser;
  }
  return null;
}
