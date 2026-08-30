import React, { useState } from 'react';
import { AppUser, Comment, InteractionType, Party } from '../types';
import { RoleBadge } from './RoleBadge';
import { PartyTagBadge } from './PartyBadges';
import { CommentSection } from './CommentSection';
import {
  ArrowLeft,
  MoreHorizontal,
  Flag,
  Link2,
  ThumbsUp,
  ThumbsDown,
  MessageSquare,
  MapPin,
  Share2
} from 'lucide-react';

interface PostDetailScreenProps {
  post: import('../types').Post;
  currentUser: AppUser;
  parties: Party[];
  comments: Comment[];
  onBack: () => void;
  onReact: (postId: string, reaction: InteractionType) => void;
  onAddComment: (postId: string, content: string, parentId?: string) => void;
  onReactComment: (commentId: string, reaction: InteractionType) => void;
  onReportPost: (postId: string, reason: string) => void;
  onReportComment: (commentId: string, reason: string) => void;
}

export const PostDetailScreen: React.FC<PostDetailScreenProps> = ({
  post,
  currentUser,
  parties,
  comments,
  onBack,
  onReact,
  onAddComment,
  onReactComment,
  onReportPost,
  onReportComment,
}) => {
  const [menuOpen, setMenuOpen] = useState(false);
  const [reporting, setReporting] = useState(false);
  const [reportReason, setReportReason] = useState('');
  const [copied, setCopied] = useState(false);

  const party = parties.find((p) => p.id === post.partyId);
  const isJanta = currentUser.role === 'janta';
  const isPartyMember = currentUser.role === 'partyMember';
  const isOwnParty = currentUser.partyId === post.partyId;
  const canInteract =
    isJanta || (isPartyMember && (post.type === 'memberTagged' || isOwnParty));

  const copyLink = () => {
    navigator.clipboard?.writeText(`${window.location.origin}/#post-${post.id}`);
    setCopied(true);
    setTimeout(() => {
      setCopied(false);
      setMenuOpen(false);
    }, 1400);
  };

  const submitPostReport = () => {
    if (!reportReason.trim()) return;
    onReportPost(post.id, reportReason.trim());
    setReporting(false);
    setReportReason('');
    setMenuOpen(false);
  };

  const formatCount = (n: number) =>
    n >= 1000000 ? `${(n / 1000000).toFixed(1)}M` : n >= 1000 ? `${(n / 1000).toFixed(1)}k` : String(n);

  return (
    <div className="max-w-2xl mx-auto px-4 py-6">
      {/* Minimal top bar: back + options */}
      <div className="flex items-center justify-between mb-6">
        <button
          onClick={onBack}
          className="inline-flex items-center gap-2 text-sm font-medium text-slate-400 hover:text-white transition-colors"
        >
          <ArrowLeft size={16} />
          <span>Back</span>
        </button>

        <div className="relative">
          <button
            onClick={() => setMenuOpen(!menuOpen)}
            aria-label="Post options"
            className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-white/5 transition-colors"
          >
            <MoreHorizontal size={18} />
          </button>

          {menuOpen && (
            <>
              <div className="fixed inset-0 z-40" onClick={() => setMenuOpen(false)} />
              <div className="absolute right-0 top-full mt-1 z-50 w-52 bg-[#0F1928] border border-[#27354F] rounded-xl shadow-xl py-1.5 overflow-hidden">
                {!reporting ? (
                  <>
                    <button
                      onClick={() => setReporting(true)}
                      className="w-full flex items-center gap-2.5 px-3.5 py-2.5 text-xs text-slate-300 hover:bg-white/5 hover:text-white transition-colors text-left"
                    >
                      <Flag size={14} className="text-amber-400" />
                      <span>Report post</span>
                    </button>
                    <button
                      onClick={copyLink}
                      className="w-full flex items-center gap-2.5 px-3.5 py-2.5 text-xs text-slate-300 hover:bg-white/5 hover:text-white transition-colors text-left"
                    >
                      {copied ? (
                        <>
                          <Share2 size={14} className="text-emerald-400" />
                          <span>Link copied</span>
                        </>
                      ) : (
                        <>
                          <Link2 size={14} />
                          <span>Copy link</span>
                        </>
                      )}
                    </button>
                  </>
                ) : (
                  <div className="p-3 space-y-2">
                    <textarea
                      rows={2}
                      autoFocus
                      value={reportReason}
                      onChange={(e) => setReportReason(e.target.value)}
                      placeholder="Why are you reporting this post?"
                      className="w-full bg-[#0A1424] border border-[#27354F] rounded-lg px-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-amber-400/50 resize-none"
                    />
                    <div className="flex gap-2 justify-end">
                      <button
                        onClick={() => {
                          setReporting(false);
                          setMenuOpen(false);
                        }}
                        className="text-[11px] text-slate-500 hover:text-slate-300 px-2 py-1"
                      >
                        Cancel
                      </button>
                      <button
                        onClick={submitPostReport}
                        disabled={!reportReason.trim()}
                        className="px-3 py-1.5 rounded-lg bg-amber-400/15 text-amber-300 text-[11px] font-semibold hover:bg-amber-400/25 disabled:opacity-40 transition-colors"
                      >
                        Submit report
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </div>

      {/* Full post article */}
      <article>
        <header className="flex items-center gap-3 mb-6">
          <div className="w-12 h-12 rounded-xl bg-[#0F1928] border border-[#27354F] flex items-center justify-center text-2xl">
            {party?.logoEmoji || '👤'}
          </div>
          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-base font-semibold text-white tracking-tight">
                {party?.name || post.authorName || 'Citizen Voice'}
              </h1>
              {party && (
                <PartyTagBadge tag={party.shortName} emoji={party.logoEmoji} small />
              )}
              {post.type === 'memberPost' && post.authorName && (
                <span className="inline-flex items-center gap-1.5 text-xs text-slate-400">
                  <span>· posted by</span>
                  <span className="text-slate-200">{post.authorName}</span>
                  <RoleBadge role="partyMember" small />
                </span>
              )}
            </div>
            <div className="flex items-center gap-2 text-xs text-slate-500 mt-1 flex-wrap">
              <span>{timeAgoShort(post.createdAt)}</span>
              {post.channelType === 'hyperLocal' && post.communityId && (
                <span className="inline-flex items-center gap-1 text-slate-400">
                  <MapPin size={11} />
                  {post.communityId}
                </span>
              )}
            </div>
          </div>
        </header>

        {post.imageEmoji && (
          <div className="text-7xl mb-6 select-none" aria-hidden>
            {post.imageEmoji}
          </div>
        )}

        <p className="text-lg text-slate-100 leading-relaxed whitespace-pre-line break-words">
          {post.content}
        </p>

        {/* Engagement row */}
        <div className="flex items-center gap-5 mt-8 pb-6 border-b border-[#16223A]">
          <button
            onClick={() => canInteract && onReact(post.id, 'like')}
            disabled={!canInteract}
            className={`inline-flex items-center gap-2 text-sm transition-colors ${
              post.interaction === 'like'
                ? 'text-emerald-400'
                : 'text-slate-500 hover:text-slate-300'
            } ${!canInteract ? 'opacity-40 cursor-not-allowed' : ''}`}
          >
            <ThumbsUp size={16} className={post.interaction === 'like' ? 'fill-current' : ''} />
            <span>{formatCount(post.likeCount)}</span>
          </button>

          <button
            onClick={() => canInteract && onReact(post.id, 'dislike')}
            disabled={!canInteract}
            className={`inline-flex items-center gap-2 text-sm transition-colors ${
              post.interaction === 'dislike'
                ? 'text-red-400'
                : 'text-slate-500 hover:text-slate-300'
            } ${!canInteract ? 'opacity-40 cursor-not-allowed' : ''}`}
          >
            <ThumbsDown size={16} className={post.interaction === 'dislike' ? 'fill-current' : ''} />
            <span>{formatCount(post.dislikeCount)}</span>
          </button>

          <span className="inline-flex items-center gap-2 text-sm text-slate-500">
            <MessageSquare size={16} />
            <span>{formatCount(comments.length)}</span>
          </span>
        </div>
      </article>

      {/* Threaded discussion */}
      <CommentSection
        postId={post.id}
        comments={comments.filter((c) => c.postId === post.id)}
        currentUserRoleCanInteract={isJanta || (isPartyMember && (post.type === 'memberTagged' || isOwnParty)) || false}
        currentUserName={
          isJanta && currentUser.isAnonymous ? 'Anonymous Citizen' : currentUser.displayName
        }
        currentUserAvatarColor={currentUser.avatarColor}
        onAddComment={onAddComment}
        onReactComment={onReactComment}
        onReportComment={onReportComment}
      />
    </div>
  );
};

function timeAgoShort(dateStr: string): string {
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}
