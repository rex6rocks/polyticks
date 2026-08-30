export type UserRole = 'janta' | 'party' | 'partyMember' | 'admin';

// Hierarchy tier roles that a Party account can assign to its members.
// Lower number = higher authority.
export type PartyRole =
  | 'president'
  | 'vice_president'
  | 'exec_committee'
  | 'general_secretary'
  | 'treasurer'
  | 'state_president'
  | 'district_president'
  | 'mandal_officer'
  | 'ground_worker';

export const PARTY_ROLE_TIERS: Record<PartyRole, number> = {
  president: 1,
  vice_president: 2,
  exec_committee: 3,
  general_secretary: 4,
  treasurer: 5,
  state_president: 6,
  district_president: 7,
  mandal_officer: 8,
  ground_worker: 9,
};

export const PARTY_ROLE_LABELS: Record<PartyRole, string> = {
  president: 'President',
  vice_president: 'Vice President',
  exec_committee: 'Executive Committee',
  general_secretary: 'General Secretary',
  treasurer: 'Treasurer',
  state_president: 'State President',
  district_president: 'District President',
  mandal_officer: 'Mandal Level Officer',
  ground_worker: 'Ground Worker',
};

// Top-tier roles assignable ONLY by the Party Official account.
// Official + these top-tier holders can assign all lower tiers.
export const TOP_TIER_PARTY_ROLES: PartyRole[] = [
  'president',
  'vice_president',
  'exec_committee',
  'general_secretary',
  'treasurer',
];

export interface AppUser {
  id: string;
  displayName: string;
  role: UserRole;
  partyId?: string; // partyMember only – which party they belong to (single-party invariant)
  partyRole?: PartyRole; // partyMember only – hierarchy tier within their party
  avatarColor: string; // fallback color when no photo
  avatarUrl?: string; // profile picture path
  email: string;
  phone?: string;
  isAnonymous: boolean; // For Janta users to hide their name in public feeds
  isVerified: boolean;
  communityId?: string; // Gated community / ward name
  createdAt: string;
}

export interface JoinRequest {
  id: string;
  userId: string;
  username: string;
  partyId: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: string;
}

export interface Party {
  id: string;
  name: string;
  shortName: string;
  description: string;
  logoEmoji: string;
  bannerColor: string;
  followerCount: number;
  memberCount: number;
  foundedYear?: number;
  ideology?: string;
}

export type PostType = 'standard' | 'memberTagged' | 'memberPost';
export type InteractionType = 'none' | 'like' | 'dislike';
export type ChannelType = 'hyperLocal' | 'broader';
export type FactCheckStatus = 'none' | 'under_review' | 'verified_context' | 'disputed' | 'auto_hidden';

export interface Post {
  id: string;
  partyId: string;
  authorId?: string; // For member posts
  authorName?: string;
  content: string;
  imageEmoji?: string;
  mediaUrl?: string;
  createdAt: string;
  likeCount: number;
  dislikeCount: number;
  commentCount: number;
  type: PostType;
  channelType: ChannelType;
  communityId?: string; // For hyper-local posts e.g. "Indiranagar Ward #84", "Palm Meadows RWA"
  interaction: InteractionType;
  editHistory: string[];
  isHidden?: boolean;
  flaggedReason?: string;
  factCheckStatus?: FactCheckStatus;
  factCheckContext?: string;
  factCheckSources?: string[];
}

export interface Comment {
  id: string;
  postId: string;
  parentId?: string; // reply target – flat storage, unlimited depth; undefined = top-level
  authorId: string;
  authorName: string;
  authorRole: UserRole;
  authorAvatarColor: string;
  authorPartyTag?: string; // denormalized shortName of author's party (partyMember only)
  authorPartyRole?: PartyRole; // denormalized hierarchy role of the author
  content: string;
  likeCount: number;
  dislikeCount: number;
  userInteraction?: InteractionType; // current viewer's reaction
  createdAt: string;
}

export interface ReportEntry {
  id: string;
  targetType: 'post' | 'comment';
  targetId: string;
  reporterId: string;
  reporterName: string;
  reason: string;
  status: 'open' | 'resolved';
  createdAt: string;
}

export interface PollOption {
  id: string;
  text: string;
  votes: number;
}

export interface Poll {
  id: string;
  partyId: string;
  question: string;
  options: PollOption[];
  endsAt: string;
  votedOptionId?: string;
  totalVotes?: number;
  communityId?: string; // ADD THIS LINE
}

export interface VerificationRequest {
  id: string;
  userId: string;
  username: string;
  phone: string;
  role: UserRole;
  imageUrl: string;
  documentType: string;
  fileSizeKb: number;
  status: 'pending' | 'approved' | 'rejected';
  submittedAt: string;
}

export interface NotificationItem {
  id: string;
  emoji: string;
  title: string;
  timeAgo: string;
  read: boolean;
  partyId?: string;
}

export interface FactCheckNote {
  id: string;
  postId: string;
  authorId: string;
  authorName: string;
  authorRole: UserRole;
  contextNote: string;
  sources: string[];
  upvotes: number;
  downvotes: number;
  createdAt: string;
  userVote?: 'upvote' | 'downvote';
}

export type SlaUrgencyLevel = 'normal' | 'warning' | 'critical' | 'breached';

export interface ParliamentaryStats {
  parliamentTerm: string;
  attendancePercentage?: number;
  debatesParticipated: number;
  questionsAsked: number;
  privateMemberBills: number;
  lastSyncedAt: string;
}

export interface AffidavitRecord {
  electionYear: number;
  immovableAssets?: number;
  movableAssets?: number;
  liabilities?: number;
  criminalChargesSummary: string[];
  sourceUrl?: string;
  scrapedAt: string;
}

export interface RepresentativeProfile {
  id: string;
  personId?: string;
  fullName: string;
  currentParty?: string;
  constituencyId?: string;
  constituencyName?: string;
  constituencyType?: string;
  designation?: string;
  totalDeclaredAssets?: number;
  activeCasesCount: number;
  educationLevel?: string;
  officialXHandle?: string;
  officialMetaHandle?: string;
  isClaimed: boolean;
  claimedByUserId?: string;
  verificationBadge: string;
  parliamentaryStats?: ParliamentaryStats;
  affidavitHistory: AffidavitRecord[];
}

export interface OfficialReply {
  id: string;
  orgId: string;
  postId: string;
  statement: string;
  status: 'draft' | 'published' | 'withdrawn';
  createdAt?: string;
}

export type OrgTier = 'basic' | 'gold' | 'platinum';

export interface OrgAnalyticsSummary {
  orgId: string;
  totalPosts: number;
  postsLast30d: number;
  totalLikes: number;
  totalDislikes: number;
  dislikeRatioPct: number;
  communityNotesReceived: number;
  trustScorePct: number;
  cleanPosts: number;
  contextAccepted: number;
  underReview: number;
  disputed: number;
  autoHidden: number;
}

export interface ModerationQueueEntry {
  id: string;
  postId: string;
  postContent: string;
  authorName: string;
  reporterName: string;
  reason: string;
  dislikeCount: number;
  likeCount: number;
  createdAt: string;
  slaDeadline: string;
  isHidden: boolean;
  factCheckStatus: FactCheckStatus;
}

