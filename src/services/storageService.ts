import { AppUser, Party, Post, Comment, Poll, VerificationRequest, InteractionType, NotificationItem, JoinRequest, PartyRole, PARTY_ROLE_TIERS, TOP_TIER_PARTY_ROLES, PARTY_ROLE_LABELS, ReportEntry, RepresentativeProfile, OfficialReply, OrgTier, OrgAnalyticsSummary } from '../types';
import {
  INITIAL_PARTIES,
  INITIAL_USERS,
  INITIAL_POSTS,
  INITIAL_COMMENTS,
  INITIAL_POLLS,
  INITIAL_FOLLOWERS,
  INITIAL_VERIFICATIONS,
  INITIAL_NOTIFICATIONS,
  INITIAL_JOIN_REQUESTS,
  INITIAL_REPRESENTATIVES
} from '../data/mockData';

const STORAGE_KEYS = {
  USERS: 'polyticks_users_v2',
  CURRENT_USER_ID: 'polyticks_current_user_id_v2',
  PARTIES: 'polyticks_parties_v2',
  POSTS: 'polyticks_posts_v2',
  COMMENTS: 'polyticks_comments_v2',
  POLLS: 'polyticks_polls_v2',
  FOLLOWERS: 'polyticks_followers_v2',
  VERIFICATIONS: 'polyticks_verifications_v2',
  NOTIFICATIONS: 'polyticks_notifications_v2',
  JOIN_REQUESTS: 'polyticks_join_requests_v2',
  REPORTS: 'polyticks_reports_v2',
  PURGE_LOG: 'polyticks_purge_log_v2',
  MEMBER_FOLLOWERS: 'polyticks_member_followers_v2',
  REPRESENTATIVES: 'polyticks_representatives_v2',
  OFFICIAL_REPLIES: 'polyticks_official_replies_v2',
  ORG_TIERS: 'polyticks_org_tiers_v2',
};

export interface PurgeRecord {
  id: string;
  userId: string;
  username: string;
  action: 'approved' | 'rejected';
  purgedAt: string;
  bytesFreed: number;
}

class StorageService {
  private get<T>(key: string, defaultValue: T): T {
    try {
      const data = localStorage.getItem(key);
      if (!data) return defaultValue;
      return JSON.parse(data) as T;
    } catch {
      return defaultValue;
    }
  }

  private set<T>(key: string, value: T): void {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (e) {
      console.error('Failed to save to localStorage:', e);
    }
  }

  // ── USER MANAGEMENT ──

  getUsers(): AppUser[] {
    return this.get<AppUser[]>(STORAGE_KEYS.USERS, INITIAL_USERS);
  }

  getCurrentUser(): AppUser {
    const users = this.getUsers();
    const currentId = this.get<string | null>(STORAGE_KEYS.CURRENT_USER_ID, 'u1');
    const found = users.find((u) => u.id === currentId);
    return found || users[0] || INITIAL_USERS[0];
  }

  setCurrentUser(userId: string): AppUser {
    this.set(STORAGE_KEYS.CURRENT_USER_ID, userId);
    return this.getCurrentUser();
  }

  updateUser(user: AppUser): void {
    const users = this.getUsers().map((u) => (u.id === user.id ? user : u));
    this.set(STORAGE_KEYS.USERS, users);
  }

  createUser(user: AppUser): AppUser {
    const users = this.getUsers();
    users.push(user);
    this.set(STORAGE_KEYS.USERS, users);
    this.setCurrentUser(user.id);
    return user;
  }

  // ── PARTIES ──

  getParties(): Party[] {
    return this.get<Party[]>(STORAGE_KEYS.PARTIES, INITIAL_PARTIES);
  }

  getPartyById(id: string): Party | undefined {
    return this.getParties().find((p) => p.id === id);
  }

  getFollowers(): Record<string, string[]> {
    return this.get<Record<string, string[]>>(STORAGE_KEYS.FOLLOWERS, INITIAL_FOLLOWERS);
  }

  isFollowing(userId: string, partyId: string): boolean {
    const user = this.getUsers().find((u) => u.id === userId);
    // Party members always follow their own party (Flutter parity)
    if (user && user.role === 'partyMember' && user.partyId === partyId) {
      return true;
    }
    const followers = this.getFollowers();
    return (followers[partyId] || []).includes(userId);
  }

  toggleFollow(userId: string, partyId: string): boolean {
    const user = this.getUsers().find((u) => u.id === userId);
    if (!user) return false;

    // Party official accounts cannot follow parties
    if (user.role === 'party') return false;

    // Party members auto-follow their own party and cannot unfollow it while a member
    if (user.role === 'partyMember' && user.partyId === partyId) {
      const followers = this.getFollowers();
      const list = followers[partyId] || [];
      if (!list.includes(userId)) {
        list.push(userId);
        followers[partyId] = list;
        this.set(STORAGE_KEYS.FOLLOWERS, followers);
      }
      return true;
    }

    const followers = this.getFollowers();
    const list = followers[partyId] || [];
    const idx = list.indexOf(userId);
    let nowFollowing = false;

    if (idx >= 0) {
      list.splice(idx, 1);
      nowFollowing = false;
    } else {
      list.push(userId);
      nowFollowing = true;
    }

    followers[partyId] = list;
    this.set(STORAGE_KEYS.FOLLOWERS, followers);

    // Update count in parties
    const parties = this.getParties().map((p) => {
      if (p.id === partyId) {
        return {
          ...p,
          followerCount: Math.max(0, p.followerCount + (nowFollowing ? 1 : -1)),
        };
      }
      return p;
    });
    this.set(STORAGE_KEYS.PARTIES, parties);

    return nowFollowing;
  }

  // ── MEMBER-LEVEL FOLLOWING (#5) ──

  getMemberFollowersMap(): Record<string, string[]> {
    return this.get<Record<string, string[]>>(STORAGE_KEYS.MEMBER_FOLLOWERS, {
      m1: ['u2', 'u3'],
      m2: ['u1'],
    });
  }

  getMemberFollowers(memberUserId: string): string[] {
    const map = this.getMemberFollowersMap();
    return map[memberUserId] || [];
  }

  isFollowingMember(memberUserId: string, currentUserId: string): boolean {
    const followers = this.getMemberFollowers(memberUserId);
    return followers.includes(currentUserId);
  }

  toggleMemberFollow(memberUserId: string, currentUserId: string): boolean {
    // Self-follows rejected (#2)
    if (memberUserId === currentUserId) return false;

    const map = this.getMemberFollowersMap();
    const list = map[memberUserId] || [];
    const idx = list.indexOf(currentUserId);
    let nowFollowing = false;

    if (idx >= 0) {
      list.splice(idx, 1);
      nowFollowing = false;
    } else {
      list.push(currentUserId);
      nowFollowing = true;
    }

    map[memberUserId] = list;
    this.set(STORAGE_KEYS.MEMBER_FOLLOWERS, map);
    return nowFollowing;
  }

  // ── PARTY MEMBERSHIP & JOIN REQUESTS ──

  private pushNotification(item: Omit<NotificationItem, 'id' | 'read'>): void {
    const list = this.getNotifications();
    list.unshift({ ...item, id: `notif_${Date.now()}`, read: false });
    this.set(STORAGE_KEYS.NOTIFICATIONS, list);
  }

  getJoinRequests(): JoinRequest[] {
    return this.get<JoinRequest[]>(STORAGE_KEYS.JOIN_REQUESTS, INITIAL_JOIN_REQUESTS);
  }

  /**
   * Janta member requests to join a party.
   * Enforces: janta-only, no existing party membership (7.b), no duplicate pending request.
   */
  requestToJoinParty(userId: string, partyId: string): { ok: boolean; reason?: string } {
    const user = this.getUsers().find((u) => u.id === userId);
    if (!user) return { ok: false, reason: 'User not found.' };
    if (user.partyId) return { ok: false, reason: 'You already belong to a party. You cannot apply until you are not part of any other party.' };

    const requests = this.getJoinRequests();
    if (requests.some((r) => r.userId === userId && r.status === 'pending')) {
      return { ok: false, reason: 'You already have a pending membership request.' };
    }
    if (requests.some((r) => r.userId === userId && r.partyId === partyId && r.status === 'approved')) {
      return { ok: false, reason: 'Your membership to this party is already active.' };
    }

    const newRequest: JoinRequest = {
      id: `jr_${Date.now()}`,
      userId,
      username: user.displayName,
      partyId,
      status: 'pending',
      createdAt: new Date().toISOString(),
    };
    requests.unshift(newRequest);
    this.set(STORAGE_KEYS.JOIN_REQUESTS, requests);

    const party = this.getPartyById(partyId);
    this.pushNotification({
      emoji: '📨',
      title: `${user.displayName} requested to join ${party?.name || 'your party'}`,
      timeAgo: 'Just now',
      partyId,
    });
    return { ok: true };
  }

  /** Party approves a membership request → account promoted to partyMember (single unified account, #8). */
  approveJoinRequest(reqId: string): void {
    const requests = this.getJoinRequests();
    const req = requests.find((r) => r.id === reqId);
    if (!req || req.status !== 'pending') return;

    req.status = 'approved';
    this.set(STORAGE_KEYS.JOIN_REQUESTS, requests);

    const users = this.getUsers();
    const user = users.find((u) => u.id === req.userId);
    if (user) {
      user.role = 'partyMember';
      user.partyId = req.partyId; // single-party invariant
      this.set(STORAGE_KEYS.USERS, users);
    }

    const parties = this.getParties().map((p) =>
      p.id === req.partyId ? { ...p, memberCount: p.memberCount + 1 } : p
    );
    this.set(STORAGE_KEYS.PARTIES, parties);

    this.pushNotification({
      emoji: '🎉',
      title: `Your membership request was approved. Welcome aboard!`,
      timeAgo: 'Just now',
      partyId: req.partyId,
    });
  }

  rejectJoinRequest(reqId: string): void {
    const requests = this.getJoinRequests();
    const req = requests.find((r) => r.id === reqId);
    if (!req || req.status !== 'pending') return;

    req.status = 'rejected';
    this.set(STORAGE_KEYS.JOIN_REQUESTS, requests);

    this.pushNotification({
      emoji: '🚫',
      title: 'Your party membership request was rejected. You may apply to other parties.',
      timeAgo: 'Just now',
    });
  }

  // ── PARTY HIERARCHY ROLES ──

  /** Can `assigner` grant/revoke roles in this party? Official: all tiers. Top-tier members: lower tiers only. */
  canManageRoles(assigner: AppUser | undefined, partyId: string): boolean {
    if (!assigner) return false;
    if (assigner.role === 'party' && assigner.partyId === partyId) return true;
    return (
      assigner.role === 'partyMember' &&
      assigner.partyId === partyId &&
      !!assigner.partyRole &&
      TOP_TIER_PARTY_ROLES.includes(assigner.partyRole)
    );
  }

  /**
   * Assign a hierarchy role to a member.
   * Rules: unique role holders per party; top-tier roles only by the Party Official;
   * non-official top-tier holders may assign strictly lower tiers than their own.
   */
  assignPartyRole(userId: string, role: PartyRole, assigner: AppUser): { ok: boolean; reason?: string } {
    const users = this.getUsers();
    const target = users.find((u) => u.id === userId);
    if (!target || target.role !== 'partyMember' || !target.partyId) {
      return { ok: false, reason: 'Target is not a party member.' };
    }
    if (!this.canManageRoles(assigner, target.partyId)) {
      return { ok: false, reason: 'You do not have authority to assign roles in this party.' };
    }

    const isOfficial = assigner.role === 'party';
    if (!isOfficial && TOP_TIER_PARTY_ROLES.includes(role)) {
      return { ok: false, reason: 'Top-tier roles can only be assigned by the Party Official account.' };
    }
    if (
      !isOfficial &&
      assigner.partyRole &&
      PARTY_ROLE_TIERS[assigner.partyRole] >= PARTY_ROLE_TIERS[role]
    ) {
      return { ok: false, reason: 'You can only assign roles strictly below your own tier.' };
    }

    // Unique role holder per party
    const clash = users.find(
      (u) => u.role === 'partyMember' && u.partyId === target.partyId && u.partyRole === role && u.id !== target.id
    );
    if (clash) {
      return { ok: false, reason: `${PARTY_ROLE_LABELS[role]} is already held by ${clash.displayName}. Roles are unique.` };
    }

    target.partyRole = role;
    this.set(STORAGE_KEYS.USERS, users);
    return { ok: true };
  }

  revokePartyRole(userId: string, revoker: AppUser): { ok: boolean; reason?: string } {
    const users = this.getUsers();
    const target = users.find((u) => u.id === userId);
    if (!target || !target.partyId) return { ok: false, reason: 'Target not found.' };
    if (!this.canManageRoles(revoker, target.partyId)) return { ok: false, reason: 'No authority to revoke roles.' };

    target.partyRole = undefined;
    this.set(STORAGE_KEYS.USERS, users);
    return { ok: true };
  }

  /** Member is removed by an authorized account → reverts to Janta, clears affiliation, unblocks join requests (7.b). */
  removeMemberFromParty(userId: string, remover: AppUser): { ok: boolean; reason?: string } {
    const users = this.getUsers();
    const target = users.find((u) => u.id === userId);
    if (!target || !target.partyId) return { ok: false, reason: 'Target is not a party member.' };
    if (!this.canManageRoles(remover, target.partyId)) return { ok: false, reason: 'No authority to remove members.' };

    this.revertToJanta(target);
    return { ok: true };
  }

  /** Self-service leave for a member. */
  leaveParty(userId: string): void {
    const users = this.getUsers();
    const target = users.find((u) => u.id === userId);
    if (!target || !target.partyId) return;
    this.revertToJanta(target);
  }

  private revertToJanta(target: AppUser): void {
    const oldPartyName = this.getPartyById(target.partyId!)?.name;

    const parties = this.getParties().map((p) =>
      p.id === target.partyId ? { ...p, memberCount: Math.max(0, p.memberCount - 1) } : p
    );
    this.set(STORAGE_KEYS.PARTIES, parties);

    target.role = 'janta';
    target.partyId = undefined;
    target.partyRole = undefined;
    const users = this.getUsers().map((u) => (u.id === target.id ? { ...target } : u));
    this.set(STORAGE_KEYS.USERS, users);

    this.pushNotification({
      emoji: '👋',
      title: `Your membership of ${oldPartyName} has ended. You are now a citizen (Janta) member again and may apply to any party.`,
      timeAgo: 'Just now',
    });
  }

  // ── POSTS ──

  getPosts(): Post[] {
    return this.get<Post[]>(STORAGE_KEYS.POSTS, INITIAL_POSTS);
  }

  createPost(post: Omit<Post, 'id' | 'createdAt' | 'likeCount' | 'dislikeCount' | 'commentCount' | 'interaction' | 'editHistory'>): Post {
    const posts = this.getPosts();
    const newPost: Post = {
      ...post,
      id: `post_${Date.now()}`,
      createdAt: new Date().toISOString(),
      likeCount: 0,
      dislikeCount: 0,
      commentCount: 0,
      interaction: 'none',
      editHistory: [],
    };
    posts.unshift(newPost);
    this.set(STORAGE_KEYS.POSTS, posts);
    return newPost;
  }

  editPost(postId: string, newContent: string): Post | undefined {
    const posts = this.getPosts();
    const post = posts.find((p) => p.id === postId);
    if (!post) return undefined;

    if (post.content !== newContent) {
      post.editHistory = [...(post.editHistory || []), post.content];
      post.content = newContent;
      this.set(STORAGE_KEYS.POSTS, posts);
    }
    return post;
  }

  reactToPost(postId: string, reaction: InteractionType): Post | undefined {
    const posts = this.getPosts();
    const post = posts.find((p) => p.id === postId);
    if (!post) return undefined;

    const previousReaction = post.interaction;

    // Undo previous
    if (previousReaction === 'like') {
      post.likeCount = Math.max(0, post.likeCount - 1);
    } else if (previousReaction === 'dislike') {
      post.dislikeCount = Math.max(0, post.dislikeCount - 1);
    }

    // Apply new
    if (reaction === previousReaction) {
      post.interaction = 'none';
    } else {
      post.interaction = reaction;
      if (reaction === 'like') {
        post.likeCount += 1;
      } else if (reaction === 'dislike') {
        post.dislikeCount += 1;
      }
    }

    this.set(STORAGE_KEYS.POSTS, posts);
    return post;
  }

  // ── COMMENTS ──

  getComments(postId?: string): Comment[] {
    const all = this.get<Comment[]>(STORAGE_KEYS.COMMENTS, INITIAL_COMMENTS);
    if (!postId) return all;
    return all.filter((c) => c.postId === postId);
  }

  addComment(postId: string, author: AppUser, content: string, parentId?: string): Comment {
    const comments = this.get<Comment[]>(STORAGE_KEYS.COMMENTS, INITIAL_COMMENTS);

    // Validate reply target belongs to the same post
    let parent: Comment | undefined;
    if (parentId) {
      parent = comments.find((c) => c.id === parentId);
      if (!parent || parent.postId !== postId) {
        parent = undefined; // orphaned reply target → degrade to top-level
      }
    }

    const newComment: Comment = {
      id: `c_${Date.now()}`,
      postId,
      parentId: parentId && parent ? parentId : undefined,
      authorId: author.id,
      authorName: author.role === 'janta' && author.isAnonymous ? 'Anonymous Citizen' : author.displayName,
      authorRole: author.role,
      authorAvatarColor: author.avatarColor,
      authorPartyTag:
        author.role === 'partyMember' ? this.getPartyById(author.partyId!)?.shortName : undefined,
      authorPartyRole: author.partyRole,
      content,
      likeCount: 0,
      dislikeCount: 0,
      createdAt: new Date().toISOString(),
    };
    comments.push(newComment);
    this.set(STORAGE_KEYS.COMMENTS, comments);

    // Update post comment count
    const posts = this.getPosts();
    const post = posts.find((p) => p.id === postId);
    if (post) {
      post.commentCount += 1;
      this.set(STORAGE_KEYS.POSTS, posts);
    }

    return newComment;
  }

  /** Toggle like/dislike on a comment (same semantics as reactToPost). */
  reactToComment(commentId: string, reaction: InteractionType): Comment | undefined {
    const comments = this.get<Comment[]>(STORAGE_KEYS.COMMENTS, INITIAL_COMMENTS);
    const comment = comments.find((c) => c.id === commentId);
    if (!comment) return undefined;

    const previous = comment.userInteraction ?? 'none';

    // Undo previous
    if (previous === 'like') {
      comment.likeCount = Math.max(0, comment.likeCount - 1);
    } else if (previous === 'dislike') {
      comment.dislikeCount = Math.max(0, comment.dislikeCount - 1);
    }

    // Apply new
    if (reaction === previous) {
      comment.userInteraction = 'none';
    } else {
      comment.userInteraction = reaction;
      if (reaction === 'like') comment.likeCount += 1;
      else if (reaction === 'dislike') comment.dislikeCount += 1;
    }

    this.set(STORAGE_KEYS.COMMENTS, comments);
    return comment;
  }

  // ── REPORTS ──

  getReports(): ReportEntry[] {
    return this.get<ReportEntry[]>(STORAGE_KEYS.REPORTS, []);
  }

  reportContent(targetType: 'post' | 'comment', targetId: string, reason: string, reporter: AppUser): ReportEntry | undefined {
    // Guard against duplicate open reports by the same user on the same target
    const reports = this.getReports();
    if (reports.some((r) => r.targetId === targetId && r.reporterId === reporter.id && r.status === 'open')) {
      return undefined;
    }
    const entry: ReportEntry = {
      id: `rep_${Date.now()}`,
      targetType,
      targetId,
      reporterId: reporter.id,
      reporterName: reporter.displayName,
      reason,
      status: 'open',
      createdAt: new Date().toISOString(),
    };
    reports.unshift(entry);
    this.set(STORAGE_KEYS.REPORTS, reports);

    // Hide reported content pending moderation
    if (targetType === 'post') {
      const posts = this.getPosts();
      const post = posts.find((p) => p.id === targetId);
      if (post && !post.isHidden) {
        post.isHidden = true;
        post.flaggedReason = `User report: ${reason}`;
        this.set(STORAGE_KEYS.POSTS, posts);
      }
    }
    return entry;
  }

  resolveReport(reportId: string, takeDown: boolean): void {
    const reports = this.getReports();
    const report = reports.find((r) => r.id === reportId);
    if (!report || report.status !== 'open') return;

    report.status = 'resolved';
    this.set(STORAGE_KEYS.REPORTS, reports);

    if (!takeDown) {
      // Restore hidden post if the report was dismissed
      if (report.targetType === 'post') {
        const posts = this.getPosts();
        const post = posts.find((p) => p.id === report.targetId);
        if (post) {
          post.isHidden = false;
          post.flaggedReason = undefined;
          this.set(STORAGE_KEYS.POSTS, posts);
        }
      }
    } else if (report.targetType === 'comment') {
      const comments = this.get<Comment[]>(STORAGE_KEYS.COMMENTS, INITIAL_COMMENTS).filter(
        (c) => c.id !== report.targetId
      );
      this.set(STORAGE_KEYS.COMMENTS, comments);
    }
  }

  // ── POLLS ──

  getPolls(partyId?: string): Poll[] {
    const all = this.get<Poll[]>(STORAGE_KEYS.POLLS, INITIAL_POLLS);
    if (!partyId) return all;
    return all.filter((p) => p.partyId === partyId);
  }

  votePoll(pollId: string, optionId: string): Poll | undefined {
    const polls = this.get<Poll[]>(STORAGE_KEYS.POLLS, INITIAL_POLLS);
    const poll = polls.find((p) => p.id === pollId);
    if (!poll) return undefined;

    if (!poll.votedOptionId) {
      poll.votedOptionId = optionId;
      const opt = poll.options.find((o) => o.id === optionId);
      if (opt) {
        opt.votes += 1;
      }
      this.set(STORAGE_KEYS.POLLS, polls);
    }
    return poll;
  }

  createPoll(poll: Poll): Poll | undefined {
    const polls = this.get<Poll[]>(STORAGE_KEYS.POLLS, INITIAL_POLLS);
    polls.unshift(poll);
    this.set(STORAGE_KEYS.POLLS, polls);
    return poll;
  }

  // ── ID VERIFICATIONS & PURGE ──

  getVerifications(): VerificationRequest[] {
    return this.get<VerificationRequest[]>(STORAGE_KEYS.VERIFICATIONS, INITIAL_VERIFICATIONS);
  }

  submitVerification(userId: string, username: string, phone: string, role: AppUser['role'], documentType: string, imageUrl: string, fileSizeKb: number): VerificationRequest {
    const list = this.getVerifications();
    // Remove previous pending if exists
    const filtered = list.filter((v) => v.userId !== userId);
    const newReq: VerificationRequest = {
      id: `ver_${Date.now()}`,
      userId,
      username,
      phone,
      role,
      imageUrl,
      documentType,
      fileSizeKb,
      status: 'pending',
      submittedAt: new Date().toISOString(),
    };
    filtered.unshift(newReq);
    this.set(STORAGE_KEYS.VERIFICATIONS, filtered);
    return newReq;
  }

  approveVerification(verId: string): void {
    const list = this.getVerifications();
    const req = list.find((v) => v.id === verId);
    if (!req) return;

    req.status = 'approved';
    this.set(STORAGE_KEYS.VERIFICATIONS, list);

    // Upgrade user
    const users = this.getUsers();
    const user = users.find((u) => u.id === req.userId);
    if (user) {
      user.isVerified = true;
      if (user.role === 'janta') {
        user.displayName = `${user.displayName.replace(' (Verified)', '')} (Verified)`;
      }
      this.set(STORAGE_KEYS.USERS, users);
    }

    // Record Zero-Retention Storage Purge
    this.recordPurge(req.userId, req.username, 'approved', req.fileSizeKb);
  }

  rejectVerification(verId: string): void {
    const list = this.getVerifications();
    const req = list.find((v) => v.id === verId);
    if (!req) return;

    req.status = 'rejected';
    this.set(STORAGE_KEYS.VERIFICATIONS, list);

    // Record Zero-Retention Storage Purge
    this.recordPurge(req.userId, req.username, 'rejected', req.fileSizeKb);
  }

  getPurgeLogs(): PurgeRecord[] {
    return this.get<PurgeRecord[]>(STORAGE_KEYS.PURGE_LOG, [
      {
        id: 'p-initial-1',
        userId: 'u1',
        username: 'Arjun Sharma',
        action: 'approved',
        purgedAt: new Date(Date.now() - 48 * 3600 * 1000).toISOString(),
        bytesFreed: 124 * 1024,
      },
      {
        id: 'p-initial-2',
        userId: 'u2',
        username: 'Priya Menon',
        action: 'approved',
        purgedAt: new Date(Date.now() - 72 * 3600 * 1000).toISOString(),
        bytesFreed: 140 * 1024,
      },
    ]);
  }

  private recordPurge(userId: string, username: string, action: 'approved' | 'rejected', fileSizeKb: number): void {
    const logs = this.getPurgeLogs();
    logs.unshift({
      id: `purge_${Date.now()}`,
      userId,
      username,
      action,
      purgedAt: new Date().toISOString(),
      bytesFreed: (fileSizeKb || 120) * 1024,
    });
    this.set(STORAGE_KEYS.PURGE_LOG, logs);
  }

  // ── NOTIFICATIONS ──

  getNotifications(): NotificationItem[] {
    return this.get<NotificationItem[]>(STORAGE_KEYS.NOTIFICATIONS, INITIAL_NOTIFICATIONS);
  }

  markAllNotificationsRead(): void {
    const list = this.getNotifications().map((n) => ({ ...n, read: true }));
    this.set(STORAGE_KEYS.NOTIFICATIONS, list);
  }

  // ── FACT CHECKING & MODERATION ──

  submitFactCheckNote(postId: string, contextNote: string, sources: string[]): Post | undefined {
    const posts = this.getPosts();
    const post = posts.find((p) => p.id === postId);
    if (!post) return undefined;

    post.factCheckStatus = 'verified_context';
    post.factCheckContext = contextNote;
    post.factCheckSources = sources;
    this.set(STORAGE_KEYS.POSTS, posts);
    return post;
  }

  resolveModerationPost(postId: string, approveRestore: boolean): void {
    const posts = this.getPosts();
    if (approveRestore) {
      const post = posts.find((p) => p.id === postId);
      if (post) {
        post.isHidden = false;
        post.factCheckStatus = 'verified_context';
        post.flaggedReason = undefined;
        this.set(STORAGE_KEYS.POSTS, posts);
      }
    } else {
      const filtered = posts.filter((p) => p.id !== postId);
      this.set(STORAGE_KEYS.POSTS, filtered);
    }
  }

  // ── REPRESENTATIVES ──

  getRepresentatives(): RepresentativeProfile[] {
    return this.get<RepresentativeProfile[]>(STORAGE_KEYS.REPRESENTATIVES, INITIAL_REPRESENTATIVES);
  }

  getRepresentativeById(id: string): RepresentativeProfile | undefined {
    return this.getRepresentatives().find((r) => r.id === id);
  }

  getRepresentativeByConstituency(constituencyName: string): RepresentativeProfile | undefined {
    return this.getRepresentatives().find(
      (r) => r.constituencyName?.toLowerCase() === constituencyName.toLowerCase()
    );
  }

  claimRepresentative(repId: string, userId: string): { success: boolean; message: string } {
    const reps = this.getRepresentatives();
    const index = reps.findIndex((r) => r.id === repId);
    if (index === -1) return { success: false, message: 'Representative profile not found.' };
    if (reps[index].isClaimed) return { success: false, message: 'This account has already been claimed.' };

    reps[index] = {
      ...reps[index],
      isClaimed: true,
      claimedByUserId: userId,
      verificationBadge: 'gold_verified',
    };
    this.set(STORAGE_KEYS.REPRESENTATIVES, reps);
    return { success: true, message: 'Account claimed successfully! Gold Verified badge applied.' };
  }

  updateRepresentativeHandles(repId: string, xHandle?: string, metaHandle?: string): void {
    const reps = this.getRepresentatives();
    const index = reps.findIndex((r) => r.id === repId);
    if (index !== -1) {
      reps[index] = {
        ...reps[index],
        officialXHandle: xHandle ?? reps[index].officialXHandle,
        officialMetaHandle: metaHandle ?? reps[index].officialMetaHandle,
      };
      this.set(STORAGE_KEYS.REPRESENTATIVES, reps);
    }
  }

  // ── OFFICIAL RIGHT-OF-REPLY ──

  getOfficialReplies(): OfficialReply[] {
    return this.get<OfficialReply[]>(STORAGE_KEYS.OFFICIAL_REPLIES, []);
  }

  getPublishedOfficialReply(postId: string): OfficialReply | undefined {
    return this.getOfficialReplies().find(
      (r) => r.postId === postId && r.status === 'published'
    );
  }

  submitOfficialReply(orgId: string, postId: string, statement: string, publish: boolean = true): OfficialReply {
    const trimmed = statement.trim();
    if (trimmed.length < 20 || trimmed.length > 2000) {
      throw new Error('Official statements must be between 20 and 2000 characters.');
    }
    const replies = this.getOfficialReplies();
    const existingIndex = replies.findIndex((r) => r.orgId === orgId && r.postId === postId);
    const reply: OfficialReply = {
      id: existingIndex >= 0 ? replies[existingIndex].id : `ror-${Date.now()}`,
      orgId,
      postId,
      statement: trimmed,
      status: publish ? 'published' : 'draft',
      createdAt: new Date().toISOString(),
    };

    if (existingIndex >= 0) {
      replies[existingIndex] = reply;
    } else {
      replies.push(reply);
    }
    this.set(STORAGE_KEYS.OFFICIAL_REPLIES, replies);
    return reply;
  }

  withdrawOfficialReply(orgId: string, postId: string): void {
    const replies = this.getOfficialReplies();
    const index = replies.findIndex((r) => r.orgId === orgId && r.postId === postId);
    if (index !== -1) {
      replies[index].status = 'withdrawn';
      this.set(STORAGE_KEYS.OFFICIAL_REPLIES, replies);
    }
  }

  // ── ORG SUBSCRIPTIONS ──

  getOrgTier(orgId: string): OrgTier {
    const tiers = this.get<Record<string, OrgTier>>(STORAGE_KEYS.ORG_TIERS, {});
    return tiers[orgId] || 'basic';
  }

  setOrgTier(orgId: string, tier: OrgTier): void {
    const tiers = this.get<Record<string, OrgTier>>(STORAGE_KEYS.ORG_TIERS, {});
    tiers[orgId] = tier;
    this.set(STORAGE_KEYS.ORG_TIERS, tiers);
  }

  // ── ORG CAMPAIGN ANALYTICS ──

  getOrgAnalyticsSummary(orgId: string): OrgAnalyticsSummary {
    const posts = this.getPosts().filter((p) => p.partyId === orgId);
    const totalPosts = posts.length;
    const totalLikes = posts.reduce((sum, p) => sum + (p.likeCount || 0), 0);
    const totalDislikes = posts.reduce((sum, p) => sum + (p.dislikeCount || 0), 0);
    const totalInteractions = totalLikes + totalDislikes;
    const dislikeRatioPct = totalInteractions > 0 ? Math.round((totalDislikes / totalInteractions) * 100) : 0;
    const cleanPosts = posts.filter((p) => !p.factCheckStatus || p.factCheckStatus === 'none').length;
    const underReview = posts.filter((p) => p.factCheckStatus === 'under_review').length;
    const disputed = posts.filter((p) => p.factCheckStatus === 'disputed').length;
    const contextAccepted = posts.filter((p) => p.factCheckStatus === 'verified_context').length;

    return {
      orgId,
      totalPosts,
      postsLast30d: totalPosts,
      totalLikes,
      totalDislikes,
      dislikeRatioPct,
      communityNotesReceived: underReview + disputed + contextAccepted,
      trustScorePct: totalPosts > 0 ? Math.round(((cleanPosts + contextAccepted) / totalPosts) * 100) : 100,
      cleanPosts,
      contextAccepted,
      underReview,
      disputed,
      autoHidden: 0,
    };
  }

  // ── RESET ──

  resetToDefault(): void {
    localStorage.removeItem(STORAGE_KEYS.USERS);
    localStorage.removeItem(STORAGE_KEYS.CURRENT_USER_ID);
    localStorage.removeItem(STORAGE_KEYS.PARTIES);
    localStorage.removeItem(STORAGE_KEYS.POSTS);
    localStorage.removeItem(STORAGE_KEYS.COMMENTS);
    localStorage.removeItem(STORAGE_KEYS.POLLS);
    localStorage.removeItem(STORAGE_KEYS.FOLLOWERS);
    localStorage.removeItem(STORAGE_KEYS.VERIFICATIONS);
    localStorage.removeItem(STORAGE_KEYS.NOTIFICATIONS);
    localStorage.removeItem(STORAGE_KEYS.JOIN_REQUESTS);
    localStorage.removeItem(STORAGE_KEYS.REPORTS);
    localStorage.removeItem(STORAGE_KEYS.PURGE_LOG);
    localStorage.removeItem(STORAGE_KEYS.REPRESENTATIVES);
    localStorage.removeItem(STORAGE_KEYS.OFFICIAL_REPLIES);
    localStorage.removeItem(STORAGE_KEYS.ORG_TIERS);
  }
}

export const storageService = new StorageService();
