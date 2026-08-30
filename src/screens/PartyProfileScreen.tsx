import React, { useState } from 'react';
import { Party, Post, Poll, AppUser, Comment, InteractionType, JoinRequest, PartyRole, PARTY_ROLE_LABELS, PARTY_ROLE_TIERS, TOP_TIER_PARTY_ROLES } from '../types';
import { PostCard } from '../components/PostCard';
import { PollCard } from '../components/PollCard';
import { CreatePollModal } from '../components/CreatePollModal';
import { UserAvatar } from '../components/UserAvatar';
import { PartyTagBadge, RoleTierBadge } from '../components/PartyBadges';
import {
  ArrowLeft,
  Award,
  UserPlus,
  UserCheck,
  Share2,
  Lock,
  PlusCircle,
  Users,
  ClipboardList,
  Check,
  X,
  UserMinus,
  BarChart3
} from 'lucide-react';

interface PartyProfileScreenProps {
  party: Party;
  currentUser: AppUser;
  allUsers: AppUser[];
  joinRequests: JoinRequest[];
  isFollowing: boolean;
  onToggleFollow: () => void;
  posts: Post[];
  comments: Comment[];
  polls: Poll[];
  onBack: () => void;
  onReact: (postId: string, reaction: InteractionType) => void;
  onAddComment: (postId: string, content: string) => void;
  onEditPost: (postId: string, newContent: string) => void;
  onVotePoll: (pollId: string, optionId: string) => void;
  onOpenCreatePost: () => void;
  onOpenCreatePoll?: () => void;
  onSubmitFactCheck?: (postId: string, contextNote: string, sources: string[]) => void;
  onRequestToJoin?: (partyId: string) => { ok: boolean; reason?: string };
  onApproveJoin?: (requestId: string) => void;
  onRejectJoin?: (requestId: string) => void;
  onAssignRole?: (userId: string, role: PartyRole) => { ok: boolean; reason?: string };
  onRevokeRole?: (userId: string) => void;
  onRemoveMember?: (userId: string) => void;
  onLeaveParty?: () => void;
  onToggleMemberFollow?: (memberId: string) => void;
  isFollowingMember?: (memberId: string) => boolean;
  getMemberFollowerCount?: (memberId: string) => number;
  onOpenPost?: (postId: string) => void;
  onCreatePoll?: (poll: Poll) => void;
}

export const PartyProfileScreen: React.FC<PartyProfileScreenProps> = ({
  party,
  currentUser,
  allUsers,
  joinRequests,
  isFollowing,
  onToggleFollow,
  posts,
  comments,
  polls,
  onBack,
  onReact,
  onAddComment,
  onEditPost,
  onVotePoll,
  onOpenCreatePost,
  onSubmitFactCheck,
  onRequestToJoin,
  onApproveJoin,
  onRejectJoin,
  onAssignRole,
  onRevokeRole,
  onRemoveMember,
  onLeaveParty,
  onToggleMemberFollow,
  isFollowingMember,
  getMemberFollowerCount,
  onOpenPost,
  onCreatePoll,
  onOpenCreatePoll,
}) => {
  const [activeTab, setActiveTab] = useState<'posts' | 'polls' | 'members' | 'about'>('posts');
  const [copiedLink, setCopiedLink] = useState(false);
  const [showCreatePoll, setShowCreatePoll] = useState(false);

  const isMember = currentUser.role === 'partyMember' && currentUser.partyId === party.id;
  const isPartyOfficial = currentUser.role === 'party' && currentUser.partyId === party.id;
  // Party accounts can always view their own party's polls.
  const canAccessPolls = isMember || isPartyOfficial;

  // Role-management authority (#6): Party Official or top-tier role holders
  const canManageRoles =
    isPartyOfficial ||
    (isMember &&
      !!currentUser.partyRole &&
      TOP_TIER_PARTY_ROLES.includes(currentUser.partyRole));

  // Party members of THIS party, ordered by hierarchy tier
  const partyMembers = allUsers
    .filter((u) => u.role === 'partyMember' && u.partyId === party.id)
    .sort(
      (a, b) =>
        (a.partyRole ? PARTY_ROLE_TIERS[a.partyRole] : 99) -
        (b.partyRole ? PARTY_ROLE_TIERS[b.partyRole] : 99)
    );

  // Roles already held by other members (roles are unique per party)
  const takenRoles = new Set(
    allUsers
      .filter((u) => u.role === 'partyMember' && u.partyId === party.id && u.id !== currentUser.id)
      .map((u) => u.partyRole)
      .filter(Boolean) as PartyRole[]
  );

  const pendingRequests = joinRequests.filter((r) => r.partyId === party.id && r.status === 'pending');
  const myPendingRequest = joinRequests.find(
    (r) => r.userId === currentUser.id && r.status === 'pending'
  );

  const partyPosts = posts.filter((p) => p.partyId === party.id);
  const partyPolls = polls.filter((p) => p.partyId === party.id);

  const handleShare = () => {
    navigator.clipboard?.writeText(window.location.href);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-6 space-y-6">
      {/* Back button */}
      <button
        onClick={onBack}
        className="inline-flex items-center gap-2 text-xs font-semibold text-slate-400 hover:text-white transition-colors"
      >
        <ArrowLeft size={16} />
        <span>Back to Feed</span>
      </button>

      {/* Party Hero Card */}
      <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] overflow-hidden shadow-2xl">
        {/* Banner Top Strip */}
        <div
          style={{ backgroundColor: party.bannerColor }}
          className="h-36 sm:h-44 w-full relative p-4 flex items-end justify-end"
        >
          <div className="absolute inset-0 bg-gradient-to-t from-[#0B1220]/80 to-transparent" />
          <button
            onClick={handleShare}
            className="relative z-10 px-3 py-1.5 rounded-xl bg-black/40 backdrop-blur-md text-white text-xs font-semibold hover:bg-black/60 transition-all flex items-center gap-1.5"
          >
            <Share2 size={13} />
            <span>{copiedLink ? 'Copied Link' : 'Share Party'}</span>
          </button>
        </div>

        {/* Profile Content */}
        <div className="px-6 pb-6 pt-0 relative">
          {/* Floating Logo and Follow Action */}
          <div className="flex items-end justify-between -mt-14 mb-4 gap-4 flex-wrap">
            <div className="w-24 h-24 rounded-2xl bg-[#1B2539] border-4 border-[#121B2E] flex items-center justify-center text-5xl shadow-2xl">
              {party.logoEmoji}
            </div>

            <div className="flex items-center gap-2.5 flex-wrap">
              {isPartyOfficial && (
                <button
                  onClick={onOpenCreatePost}
                  className="px-4 py-2.5 rounded-xl bg-[#FF7A2F] text-white text-xs font-bold shadow-md shadow-orange-500/25 hover:brightness-110 flex items-center gap-1.5 transition-all"
                >
                  <PlusCircle size={15} />
                  <span>Official Broadcast</span>
                </button>
              )}

              {/* Join request flow (#7): Janta users may request membership */}
              {currentUser.role === 'janta' && onRequestToJoin && (
                myPendingRequest ? (
                  <button
                    disabled
                    className="px-5 py-2.5 rounded-xl bg-[#1B2539] text-slate-300 text-xs font-bold border border-[#33415C] flex items-center gap-2 cursor-not-allowed"
                  >
                    <ClipboardList size={15} />
                    <span>Membership Request Pending</span>
                  </button>
                ) : (
                  <button
                    onClick={() => onRequestToJoin(party.id)}
                    className="px-5 py-2.5 rounded-xl bg-[#E8AE33]/20 text-[#E8AE33] border border-[#E8AE33]/40 text-xs font-bold flex items-center gap-2 hover:bg-[#E8AE33]/30 transition-all"
                    title="Request to become a member of this party"
                  >
                    <UserPlus size={15} />
                    <span>Request Membership</span>
                  </button>
                )
              )}

              {/* Leave party action for verified members */}
              {isMember && onLeaveParty && (
                <button
                  onClick={() => {
                    if (window.confirm(`Are you sure you want to leave ${party.name}? You will revert to a Janta citizen account.`)) {
                      onLeaveParty();
                    }
                  }}
                  className="px-4 py-2.5 rounded-xl bg-red-500/15 text-red-400 border border-red-500/30 text-xs font-bold hover:bg-red-500/25 transition-all flex items-center gap-1.5"
                >
                  <UserMinus size={15} />
                  <span>Leave Party</span>
                </button>
              )}

              <button
                onClick={onToggleFollow}
                className={`px-5 py-2.5 rounded-xl text-xs font-bold flex items-center gap-2 transition-all ${
                  isFollowing
                    ? 'bg-[#1B2539] text-slate-200 border border-[#33415C] hover:border-red-500/50 hover:text-red-400'
                    : 'bg-gradient-to-r from-[#FF7A2F] to-[#E86A24] text-white elevate-sm hover:brightness-110'
                }`}
              >
                {isFollowing ? (
                  <>
                    <UserCheck size={15} className="text-[#21B579]" />
                    <span>Following</span>
                  </>
                ) : (
                  <>
                    <UserPlus size={15} />
                    <span>Follow Party</span>
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Party Title & Tagline */}
          <div className="space-y-1">
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-2xl font-bold font-display text-white">
                {party.name}
              </h1>
              <span className="text-xs font-bold px-2.5 py-0.5 rounded-full bg-[#E8697A]/15 text-[#E8697A] border border-[#E8697A]/30">
                {party.shortName}
              </span>
              {isMember && (
                <span className="text-xs font-bold px-2.5 py-0.5 rounded-full bg-[#E8AE33]/15 text-[#E8AE33] border border-[#E8AE33]/30 flex items-center gap-1">
                  <Award size={12} /> You are a Verified Member
                </span>
              )}
            </div>

            <p className="text-xs sm:text-sm text-slate-300 max-w-2xl leading-relaxed">
              {party.description}
            </p>
          </div>

          {/* Stat Chips Row */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-6 pt-5 border-t border-[#27354F]">
            <div className="bg-[#1B2539] p-3 rounded-xl border border-[#27354F] text-center">
              <p className="text-base font-bold font-display text-white">
                {party.followerCount.toLocaleString()}
              </p>
              <p className="text-[11px] text-slate-400">Citizens Following</p>
            </div>

            <div className="bg-[#1B2539] p-3 rounded-xl border border-[#27354F] text-center">
              <p className="text-base font-bold font-display text-[#E8AE33]">
                {party.memberCount.toLocaleString()}
              </p>
              <p className="text-[11px] text-slate-400">Verified Members</p>
            </div>

            <div className="bg-[#1B2539] p-3 rounded-xl border border-[#27354F] text-center">
              <p className="text-base font-bold font-display text-white">
                {partyPosts.length}
              </p>
              <p className="text-[11px] text-slate-400">Public Releases</p>
            </div>

            <div className="bg-[#1B2539] p-3 rounded-xl border border-[#27354F] text-center">
              <p className="text-base font-bold font-display text-[#3FBFB4]">
                {party.foundedYear || 2012}
              </p>
              <p className="text-[11px] text-slate-400">Founded Year</p>
            </div>
          </div>
        </div>
      </div>

      {/* Pending Membership Requests Panel (#7) – visible to party account & role managers */}
      {(isPartyOfficial || canManageRoles) && pendingRequests.length > 0 && (
        <div className="bg-[#121B2E] rounded-2xl border border-[#E8AE33]/40 p-5 space-y-3">
          <h3 className="font-display font-bold text-sm text-white flex items-center gap-2">
            <ClipboardList size={16} className="text-[#E8AE33]" />
            <span>Pending Membership Requests ({pendingRequests.length})</span>
          </h3>
          <div className="space-y-2.5">
            {pendingRequests.map((req) => {
              const requester = allUsers.find((u) => u.id === req.userId);
              return (
                <div
                  key={req.id}
                  className="flex items-center justify-between gap-3 p-3 rounded-xl bg-[#1B2539] border border-[#27354F] flex-wrap"
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <UserAvatar user={requester || null} size="sm" />
                    <div>
                      <p className="text-xs font-bold text-white">{req.username}</p>
                      <p className="text-[10px] text-slate-400">
                        Requested {new Date(req.createdAt).toLocaleDateString()} · Community: {requester?.communityId || 'N/A'}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {onApproveJoin && (
                      <button
                        onClick={() => onApproveJoin(req.id)}
                        className="px-3 py-1.5 rounded-lg bg-[#21B579]/20 text-[#21B579] border border-[#21B579]/40 text-xs font-bold hover:bg-[#21B579]/30 transition-all flex items-center gap-1"
                      >
                        <Check size={13} /> Approve
                      </button>
                    )}
                    {onRejectJoin && (
                      <button
                        onClick={() => onRejectJoin(req.id)}
                        className="px-3 py-1.5 rounded-lg bg-red-500/15 text-red-400 border border-red-500/30 text-xs font-bold hover:bg-red-500/25 transition-all flex items-center gap-1"
                      >
                        <X size={13} /> Reject
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Tabs Row */}
      <div className="flex items-center gap-2 border-b border-[#27354F] pb-2 text-xs font-bold">
        <button
          onClick={() => setActiveTab('posts')}
          className={`px-4 py-2 rounded-xl transition-all ${
            activeTab === 'posts'
              ? 'bg-[#FF7A2F] text-white shadow-md shadow-orange-500/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          Party Posts ({partyPosts.length})
        </button>

        <button
          onClick={() => setActiveTab('polls')}
          className={`px-4 py-2 rounded-xl transition-all ${
            activeTab === 'polls'
              ? 'bg-[#FF7A2F] text-white shadow-md shadow-orange-500/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          Members Ballots ({partyPolls.length})
        </button>

        <button
          onClick={() => setActiveTab('members')}
          className={`px-4 py-2 rounded-xl transition-all ${
            activeTab === 'members'
              ? 'bg-[#FF7A2F] text-white shadow-md shadow-orange-500/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          Members ({partyMembers.length})
        </button>

        <button
          onClick={() => setActiveTab('about')}
          className={`px-4 py-2 rounded-xl transition-all ${
            activeTab === 'about'
              ? 'bg-[#FF7A2F] text-white shadow-md shadow-orange-500/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          Manifesto & Ideology
        </button>
      </div>

      {/* Tab Contents */}
      {activeTab === 'posts' && (
        <div className="space-y-4">
          {partyPosts.length === 0 ? (
            <div className="p-8 text-center bg-[#121B2E] rounded-2xl border border-[#27354F] text-slate-400 text-xs">
              No posts released by {party.shortName} yet.
            </div>
          ) : (
            partyPosts.map((post) => (
              <PostCard
                key={post.id}
                post={post}
                party={party}
                currentUser={currentUser}
                comments={comments.filter((c) => c.postId === post.id)}
                onReact={onReact}
                onAddComment={onAddComment}
                onEditPost={onEditPost}
                onSubmitFactCheck={onSubmitFactCheck}
                onOpenPost={onOpenPost}
              />
            ))
          )}
        </div>
      )}

      {activeTab === 'polls' && (
        <div className="space-y-4">
          {!canAccessPolls && (
            <div className="p-4 rounded-2xl bg-[#121B2E] border border-[#27354F] text-xs text-slate-300 flex items-center gap-3">
              <Lock size={18} className="text-[#E8AE33] shrink-0" />
              <div>
                <span className="font-bold text-white block">Members-Only Voting Gate</span>
                You are currently browsing in citizen observer mode. Only verified members of {party.name} can submit votes in these internal policy ballots.
              </div>
            </div>
          )}

          {partyPolls.length === 0 ? (
            <div className="p-8 text-center bg-[#121B2E] rounded-2xl border border-[#27354F] text-slate-400 text-xs">
              No active member ballots for {party.shortName} at the moment.
            </div>
          ) : (
            partyPolls.map((poll) => (
              <PollCard
                key={poll.id}
                poll={poll}
                party={party}
                currentUser={currentUser}
                onVote={onVotePoll}
              />
            ))
          )}
        </div>
      )}

      {activeTab === 'members' && (
        <div className="space-y-4">
          <div className="p-4 rounded-2xl bg-[#121B2E] border border-[#27354F] text-xs text-slate-300 flex items-center gap-3 flex-wrap">
            <Users size={16} className="text-[#FF7A2F] shrink-0" />
            <span>
              Party hierarchy of <span className="text-white font-bold">{party.name}</span>.
              Roles are unique per party. Top-tier roles are assigned by the Party Official account;
              top-tier holders can assign roles below their own tier.
            </span>
          </div>

          {partyMembers.length === 0 ? (
            <div className="p-8 text-center bg-[#121B2E] rounded-2xl border border-[#27354F] text-slate-400 text-xs">
              No registered members yet.
            </div>
          ) : (
            partyMembers.map((member) => (
              <div
                key={member.id}
                className="flex items-center justify-between gap-3 p-4 rounded-2xl bg-[#121B2E] border border-[#27354F] flex-wrap"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <UserAvatar user={member} size="md" />
                  <div className="min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <p className="text-sm font-bold text-white truncate">{member.displayName}</p>
                      <PartyTagBadge tag={party.shortName} emoji={party.logoEmoji} small />
                      {member.partyRole && <RoleTierBadge role={member.partyRole} small />}
                    </div>
                    <p className="text-[10px] text-slate-400 mt-0.5 truncate flex items-center gap-2">
                      <span>{member.communityId || member.email}</span>
                      {getMemberFollowerCount && (
                        <span>· {getMemberFollowerCount(member.id)} followers</span>
                      )}
                    </p>
                  </div>
                </div>

                {/* Member Actions Row */}
                <div className="flex items-center gap-2 flex-wrap">
                  {/* Individual Member Follow Button (#5) */}
                  {onToggleMemberFollow && isFollowingMember && member.id !== currentUser.id && (
                    <button
                      onClick={() => onToggleMemberFollow(member.id)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 ${
                        isFollowingMember(member.id)
                          ? 'bg-[#1B2539] text-slate-300 border border-[#27354F]'
                          : 'bg-[#FF7A2F]/20 text-[#FF7A2F] border border-[#FF7A2F]/40 hover:bg-[#FF7A2F]/30'
                      }`}
                    >
                      {isFollowingMember(member.id) ? (
                        <>
                          <UserCheck size={13} className="text-[#21B579]" />
                          <span>Following</span>
                        </>
                      ) : (
                        <>
                          <UserPlus size={13} />
                          <span>Follow</span>
                        </>
                      )}
                    </button>
                  )}

                  {/* Role Management (#6) */}
                {canManageRoles && onAssignRole && (
                  <div className="flex items-center gap-2 flex-wrap">
                    <select
                      value={member.partyRole || ''}
                      onChange={(e) => {
                        if (e.target.value) {
                          onAssignRole(member.id, e.target.value as PartyRole);
                        }
                      }}
                      aria-label={`Assign role to ${member.displayName}`}
                      className="bg-[#0B1220] border border-[#27354F] rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-[#FF7A2F]"
                    >
                      <option value="" disabled>
                        Assign role…
                      </option>
                      {(Object.keys(PARTY_ROLE_LABELS) as PartyRole[])
                        .filter((role) => !takenRoles.has(role))
                        .map((role) => {
                          const topTier = TOP_TIER_PARTY_ROLES.includes(role);
                          const belowOwn =
                            isPartyOfficial ||
                            (currentUser.partyRole &&
                              PARTY_ROLE_TIERS[currentUser.partyRole] < PARTY_ROLE_TIERS[role]);
                          return (
                            <option key={role} value={role} disabled={topTier ? !isPartyOfficial : !belowOwn}>
                              {PARTY_ROLE_LABELS[role]}
                              {!belowOwn && !isPartyOfficial ? ' (above your tier)' : ''}
                            </option>
                          );
                        })}
                    </select>

                    {onRevokeRole && member.partyRole && (
                      <button
                        onClick={() => onRevokeRole(member.id)}
                        title="Revoke role"
                        aria-label={`Revoke role of ${member.displayName}`}
                        className="px-2.5 py-2 rounded-lg bg-[#0B1220] border border-[#33415C] text-slate-400 hover:text-white transition-colors"
                      >
                        <X size={14} />
                      </button>
                    )}

                    {onRemoveMember && (
                      <button
                        onClick={() => onRemoveMember(member.id)}
                        title="Remove from party (reverts to Janta)"
                        aria-label={`Remove ${member.displayName} from party`}
                        className="px-2.5 py-2 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 hover:bg-red-500/20 transition-colors"
                      >
                        <UserMinus size={14} />
                      </button>
                    )}
                  </div>
                )}
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {activeTab === 'about' && (
        <div className="bg-[#121B2E] rounded-2xl border border-[#27354F] p-6 space-y-5">
          <div>
            <h3 className="text-sm font-bold uppercase tracking-wider text-slate-400 mb-2">
              Political Philosophy & Platform
            </h3>
            <p className="text-sm text-slate-200 leading-relaxed">
              {party.ideology || 'Committed to constitutional integrity, civic progress, and sustainable economic reform.'}
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-4 border-t border-[#27354F]">
            <div className="p-4 rounded-xl bg-[#1B2539] border border-[#27354F]">
              <h4 className="font-bold text-xs text-[#FF7A2F] uppercase mb-1">
                Transparency Standard
              </h4>
              <p className="text-xs text-slate-300">
                All policy consultation outcomes on Polyticks are published with cryptographic integrity records.
              </p>
            </div>

            <div className="p-4 rounded-xl bg-[#1B2539] border border-[#27354F]">
              <h4 className="font-bold text-xs text-[#21B579] uppercase mb-1">
                Democratic Membership
              </h4>
              <p className="text-xs text-slate-300">
                Verified members participate directly in agenda setting and local ward prioritization polls.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Floating Action Button: party official can create polls on Polls tab */}
      {isPartyOfficial && activeTab === 'polls' && (
        <button
          onClick={() => {
            // Prefer parent's onOpenCreatePoll (hoists modal to App.tsx root
            // so it can never be obscured by other z-50 modals like
            // CreatePostModal that App.tsx renders AFTER this screen).
            if (onOpenCreatePoll) {
              onOpenCreatePoll();
            } else {
              setShowCreatePoll(true);
            }
          }}
          aria-label="Create new party poll"
          className="fixed bottom-6 right-6 z-[60] w-14 h-14 rounded-full bg-[#FF7A2F] text-white shadow-2xl shadow-orange-500/40 hover:bg-[#E8AE33] hover:scale-105 active:scale-95 transition-all flex items-center justify-center"
          title="Create new poll"
        >
          <BarChart3 size={22} />
        </button>
      )}

      {/* Fallback: Create Poll Modal rendered locally if no parent handler.
          Note: When App.tsx passes onOpenCreatePoll, this code is dead, but
          keeps the screen usable in isolation (e.g. Storybook). */}
      {showCreatePoll && !onOpenCreatePoll && (
        <CreatePollModal
          party={party}
          currentUser={currentUser}
          onClose={() => setShowCreatePoll(false)}
          onCreate={(newPoll) => {
            // Push the new poll up to the parent so it persists in App state.
            if (onCreatePoll) {
              onCreatePoll(newPoll);
            } else {
              // Local fallback: prepend to in-memory list
              polls.unshift(newPoll);
            }
            setShowCreatePoll(false);
          }}
        />
      )}
    </div>
  );
};
