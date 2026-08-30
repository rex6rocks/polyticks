import React, { useState, useMemo } from 'react';
import { Post, Party, AppUser, Comment, Poll, InteractionType, ChannelType } from '../types';
import { PostCard } from '../components/PostCard';
import { PollCard } from '../components/PollCard';
import {
  Globe,
  MapPin,
  Search,
  PlusCircle,
  Sparkles,
  Building2,
  CheckCircle2
} from 'lucide-react';

interface FeedScreenProps {
  currentUser: AppUser;
  parties: Party[];
  posts: Post[];
  comments: Comment[];
  polls: Poll[];
  onReact: (postId: string, reaction: InteractionType) => void;
  onAddComment: (postId: string, content: string) => void;
  onEditPost: (postId: string, newContent: string) => void;
  onVotePoll: (pollId: string, optionId: string) => void;
  onPartyClick: (partyId: string) => void;
  onOpenPost?: (postId: string) => void;
  onOpenCreatePost: () => void;
  onOpenVerification: () => void;
  onSubmitFactCheck?: (postId: string, contextNote: string, sources: string[]) => void;
}

export const FeedScreen: React.FC<FeedScreenProps> = ({
  currentUser,
  parties,
  posts,
  comments,
  polls,
  onReact,
  onAddComment,
  onEditPost,
  onVotePoll,
  onPartyClick,
  onOpenPost,
  onOpenCreatePost,
  onOpenVerification,
  onSubmitFactCheck,
}) => {
  const [selectedChannel, setSelectedChannel] = useState<ChannelType>('broader');
  const [activeTab, setActiveTab] = useState<'all' | 'parties' | 'discussions' | 'polls'>('all');
  const [searchQuery, setSearchQuery] = useState('');

  // Filtered Posts
  const filteredPosts = useMemo(() => {
    return posts.filter((post) => {
      // Channel match
      if (selectedChannel === 'hyperLocal' && post.channelType !== 'hyperLocal') {
        return false;
      }
      if (selectedChannel === 'broader' && post.channelType === 'hyperLocal') {
        return false;
      }

      // Tab match
      if (activeTab === 'parties' && post.type !== 'standard') return false;
      if (activeTab === 'discussions' && post.type !== 'memberTagged' && post.type !== 'memberPost') return false;

      // Search match
      if (searchQuery.trim()) {
        const query = searchQuery.toLowerCase();
        const contentMatch = post.content.toLowerCase().includes(query);
        const party = parties.find((p) => p.id === post.partyId);
        const partyMatch = party?.name.toLowerCase().includes(query) || party?.shortName.toLowerCase().includes(query);
        return contentMatch || partyMatch;
      }

      return true;
    });
  }, [posts, selectedChannel, activeTab, searchQuery, parties]);

  // Relevant Polls for the feed
  const relevantPolls = useMemo(() => {
    if (activeTab === 'parties' || activeTab === 'discussions') return [];
    if (searchQuery.trim()) {
      return polls.filter((p) => p.question.toLowerCase().includes(searchQuery.toLowerCase()));
    }
    return polls;
  }, [polls, activeTab, searchQuery]);

  return (
    <div className="max-w-6xl mx-auto px-4 py-6">
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Main Feed Column (8 cols) */}
        <main className="lg:col-span-8 space-y-5">
          {/* Dual Channel Switcher Banner */}
          <div className="bg-[#121B2E] rounded-2xl border border-[#27354F] p-2 flex items-center justify-between gap-2 shadow-md">
            <button
              onClick={() => setSelectedChannel('broader')}
              className={`flex-1 py-2.5 px-4 rounded-xl text-xs sm:text-sm font-bold flex items-center justify-center gap-2 transition-all ${
                selectedChannel === 'broader'
                  ? 'bg-[#FF7A2F] text-white elevate-sm'
                  : 'text-slate-400 hover:text-white hover:bg-white/5'
              }`}
            >
              <Globe size={16} />
              <span>Broader & National</span>
            </button>

            <button
              onClick={() => setSelectedChannel('hyperLocal')}
              className={`flex-1 py-2.5 px-4 rounded-xl text-xs sm:text-sm font-bold flex items-center justify-center gap-2 transition-all ${
                selectedChannel === 'hyperLocal'
                  ? 'bg-[#3FBFB4] text-[#0B1220] elevate-sm'
                  : 'text-slate-400 hover:text-white hover:bg-white/5'
              }`}
            >
              <MapPin size={16} />
              <span>Hyper-Local (Ward #84)</span>
            </button>
          </div>

          {/* Verification Reminder Banner if User is Not Verified */}
          {!currentUser.isVerified && (
            <div className="p-4 rounded-2xl bg-gradient-to-r from-[#FF7A2F]/15 via-[#FF8833]/10 to-transparent border border-[#FF7A2F]/30 flex items-center justify-between gap-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#FF7A2F]/20 flex items-center justify-center text-xl shrink-0">
                  🛡️
                </div>
                <div>
                  <h4 className="text-xs sm:text-sm font-bold text-white font-display">
                    Civic Verification Available
                  </h4>
                  <p className="text-[11px] text-slate-300">
                    Verify government ID with our on-device zero-retention system to post and vote in ward ballots.
                  </p>
                </div>
              </div>
              <button
                onClick={onOpenVerification}
                className="px-3.5 py-2 rounded-xl bg-[#FF7A2F] hover:bg-[#E86A24] text-white text-xs font-bold whitespace-nowrap shadow-sm transition-all"
              >
                Verify ID
              </button>
            </div>
          )}

          {/* Tab Filter & Search Bar */}
          <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
            {/* Filter Tabs */}
            <div className="flex items-center bg-[#121B2E] p-1 rounded-xl border border-[#27354F] text-xs font-semibold">
              <button
                onClick={() => setActiveTab('all')}
                className={`px-3 py-1.5 rounded-lg transition-all ${
                  activeTab === 'all'
                    ? 'bg-[#FF7A2F] text-white'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                All Feed
              </button>
              <button
                onClick={() => setActiveTab('parties')}
                className={`px-3 py-1.5 rounded-lg transition-all ${
                  activeTab === 'parties'
                    ? 'bg-[#FF7A2F] text-white'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Official
              </button>
              <button
                onClick={() => setActiveTab('discussions')}
                className={`px-3 py-1.5 rounded-lg transition-all ${
                  activeTab === 'discussions'
                    ? 'bg-[#FF7A2F] text-white'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Consultations
              </button>
              <button
                onClick={() => setActiveTab('polls')}
                className={`px-3 py-1.5 rounded-lg transition-all ${
                  activeTab === 'polls'
                    ? 'bg-[#FF7A2F] text-white'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                Polls
              </button>
            </div>

            {/* Search Input */}
            <div className="relative flex-1 sm:max-w-xs">
              <Search
                size={14}
                className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
              />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search posts, wards, topics..."
                className="w-full bg-[#121B2E] border border-[#27354F] rounded-xl pl-9 pr-3.5 py-1.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-[#FF7A2F]"
              />
            </div>
          </div>

          {/* Feed Content */}
          <div className="space-y-4">
            {activeTab === 'polls' ? (
              // Polls Tab View
              relevantPolls.length === 0 ? (
                <div className="p-8 text-center bg-[#121B2E] rounded-2xl border border-[#27354F] text-slate-400 text-xs">
                  No active ballots found for this filter.
                </div>
              ) : (
                relevantPolls.map((poll) => (
                  <PollCard
                    key={poll.id}
                    poll={poll}
                    party={parties.find((p) => p.id === poll.partyId)}
                    currentUser={currentUser}
                    onVote={onVotePoll}
                    onPartyClick={onPartyClick}
                  />
                ))
              )
            ) : (
              // Combined Posts & Injected Polls View
              <>
                {/* Member-Only Ballot Widget injected at top if broader feed and all selected */}
                {activeTab === 'all' && relevantPolls.length > 0 && (
                  <div className="mb-4">
                    <PollCard
                      poll={relevantPolls[0]}
                      party={parties.find((p) => p.id === relevantPolls[0].partyId)}
                      currentUser={currentUser}
                      onVote={onVotePoll}
                      onPartyClick={onPartyClick}
                    />
                  </div>
                )}

                {filteredPosts.length === 0 ? (
                  <div className="p-12 text-center bg-[#121B2E] rounded-2xl border border-[#27354F]">
                    <span className="text-4xl mb-3 block">📭</span>
                    <h3 className="text-sm font-bold text-white mb-1 font-display">
                      No posts match your filters
                    </h3>
                    <p className="text-xs text-slate-400 max-w-sm mx-auto mb-4">
                      Try selecting a different channel, clearing the search query, or switching tabs.
                    </p>
                    <button
                      onClick={() => {
                        setSearchQuery('');
                        setActiveTab('all');
                      }}
                      className="px-4 py-2 bg-[#1B2539] hover:bg-[#27354F] text-white rounded-xl text-xs font-semibold"
                    >
                      Reset Filters
                    </button>
                  </div>
                ) : (
                  filteredPosts.map((post) => (
                    <PostCard
                      key={post.id}
                      post={post}
                      party={parties.find((p) => p.id === post.partyId)}
                      currentUser={currentUser}
                      comments={comments.filter((c) => c.postId === post.id)}
                      onReact={onReact}
                      onAddComment={onAddComment}
                      onEditPost={onEditPost}
                      onPartyClick={onPartyClick}
                      onOpenPost={onOpenPost}
                      onSubmitFactCheck={onSubmitFactCheck}
                    />
                  ))
                )}
              </>
            )}
          </div>
        </main>

        {/* Sidebar (4 cols on desktop) */}
        <aside className="hidden lg:block lg:col-span-4 space-y-5">
          {/* User Civic Status Card */}
          <div className="bg-[#121B2E] rounded-2xl border border-[#27354F] p-5 shadow-lg">
            <div className="flex items-center gap-3 mb-3">
              <div
                style={{ backgroundColor: currentUser.avatarColor }}
                className="w-12 h-12 rounded-xl flex items-center justify-center font-bold text-white text-lg shadow-sm"
              >
                {currentUser.displayName.charAt(0)}
              </div>
              <div className="overflow-hidden">
                <h3 className="font-display font-bold text-sm text-white truncate">
                  {currentUser.displayName}
                </h3>
                <p className="text-xs text-slate-400 capitalize">
                  Role: <span className="text-slate-200 font-medium">{currentUser.role}</span>
                </p>
              </div>
            </div>

            <div className="p-3 bg-[#1B2539] rounded-xl border border-[#27354F] space-y-2 mb-3">
              <div className="flex items-center justify-between text-xs">
                <span className="text-slate-400">Civic Verification:</span>
                {currentUser.isVerified ? (
                  <span className="text-[#21B579] font-bold flex items-center gap-1">
                    <CheckCircle2 size={12} /> Verified ID
                  </span>
                ) : (
                  <span className="text-amber-400 font-bold">Unverified</span>
                )}
              </div>
              {currentUser.communityId && (
                <div className="flex items-center justify-between text-xs">
                  <span className="text-slate-400">Assigned Ward:</span>
                  <span className="text-slate-200 font-semibold truncate max-w-[120px]">
                    {currentUser.communityId}
                  </span>
                </div>
              )}
            </div>

            <button
              onClick={onOpenCreatePost}
              className="w-full py-2.5 bg-[#FF7A2F] hover:bg-[#E86A24] text-white rounded-xl text-xs font-bold flex items-center justify-center gap-2 shadow-md shadow-orange-500/20 transition-all"
            >
              <PlusCircle size={15} />
              <span>Create New Post</span>
            </button>
          </div>

          {/* Registered Political Parties Widget */}
          <div className="bg-[#121B2E] rounded-2xl border border-[#27354F] p-5 shadow-lg space-y-3">
            <div className="flex items-center justify-between">
              <h3 className="font-display font-bold text-sm text-white flex items-center gap-1.5">
                <Building2 size={16} className="text-[#FF7A2F]" />
                <span>Recognized Parties</span>
              </h3>
              <span className="text-[11px] text-slate-400">
                {parties.length} Registered
              </span>
            </div>

            <div className="space-y-2.5">
              {parties.map((party) => (
                <div
                  key={party.id}
                  onClick={() => onPartyClick(party.id)}
                  className="p-3 rounded-xl bg-[#1B2539] border border-[#27354F] hover:border-slate-500 cursor-pointer transition-all flex items-center justify-between gap-3 group"
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <span className="text-2xl group-hover:scale-110 transition-transform">
                      {party.logoEmoji}
                    </span>
                    <div className="truncate">
                      <p className="text-xs font-bold text-white truncate">
                        {party.name}
                      </p>
                      <p className="text-[10px] text-slate-400 truncate">
                        {party.followerCount.toLocaleString()} followers · {party.memberCount.toLocaleString()} members
                      </p>
                    </div>
                  </div>
                  <span className="text-xs font-bold text-[#FF7A2F] group-hover:translate-x-0.5 transition-transform">
                    →
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Civic Principles Card */}
          <div className="bg-[#121B2E]/70 rounded-2xl border border-[#27354F] p-4 text-xs text-slate-400 space-y-2">
            <h4 className="font-bold text-white flex items-center gap-1.5">
              <Sparkles size={14} className="text-amber-400" />
              <span>Polyticks Civic Commitments</span>
            </h4>
            <ul className="space-y-1.5 text-[11px] list-disc list-inside text-slate-300">
              <li>Zero-knowledge, auto-purged government ID verification.</li>
              <li>Uncensored civic dislike counts for policy transparency.</li>
              <li>Hyper-local ward granularity and community context notes.</li>
            </ul>
          </div>
        </aside>
      </div>
    </div>
  );
};
