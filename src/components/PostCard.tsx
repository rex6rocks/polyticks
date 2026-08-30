import React, { useState } from 'react';
import { Post, AppUser, Party, Comment, InteractionType } from '../types';
import { UserAvatar } from './UserAvatar';
import { RoleBadge } from './RoleBadge';
import { PartyTagBadge, RoleTierBadge } from './PartyBadges';
import { SubmitFactCheckModal } from './SubmitFactCheckModal';
import {
  ThumbsUp,
  ThumbsDown,
  MessageSquare,
  Share2,
  Lock,
  Edit3,
  History,
  AlertTriangle,
  ExternalLink,
  Send,
  MapPin,
  X,
  FileText
} from 'lucide-react';

interface PostCardProps {
  post: Post;
  party?: Party;
  currentUser: AppUser;
  comments: Comment[];
  onReact: (postId: string, reaction: InteractionType) => void;
  onAddComment: (postId: string, content: string) => void;
  onEditPost: (postId: string, newContent: string) => void;
  onPartyClick?: (partyId: string) => void;
  onOpenPost?: (postId: string) => void;
  onSubmitFactCheck?: (postId: string, contextNote: string, sources: string[]) => void;
}

export const PostCard: React.FC<PostCardProps> = ({
  post,
  party,
  currentUser,
  comments,
  onReact,
  onAddComment,
  onEditPost,
  onPartyClick,
  onOpenPost,
  onSubmitFactCheck,
}) => {
  const [showComments, setShowComments] = useState(false);
  const [commentText, setCommentText] = useState('');
  const [showEditModal, setShowEditModal] = useState(false);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [showFactCheckModal, setShowFactCheckModal] = useState(false);
  const [editContent, setEditContent] = useState(post.content);
  const [copiedLink, setCopiedLink] = useState(false);

  // Permission Logic:
  // - Janta (Citizens): Can interact with any post (like/dislike/comment)
  // - Party Official: Cannot like/dislike posts (neutral broadcast identity), can edit own party posts
  // - Party Member: Can like/dislike tagged member posts or their own party posts
  const isJanta = currentUser.role === 'janta';
  const isPartyOfficial = currentUser.role === 'party';
  const isPartyMember = currentUser.role === 'partyMember';
  const isOwnParty = currentUser.partyId === post.partyId;

  const canLike =
    isJanta || (isPartyMember && (post.type === 'memberTagged' || isOwnParty));

  const canComment =
    isJanta || (isPartyMember && (post.type === 'memberTagged' || isOwnParty));

  const canEdit =
    (isPartyOfficial && isOwnParty) ||
    (post.authorId && post.authorId === currentUser.id);

  const handleSendComment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!commentText.trim() || !canComment) return;
    onAddComment(post.id, commentText.trim());
    setCommentText('');
  };

  const handleSaveEdit = () => {
    if (editContent.trim() && editContent.trim() !== post.content) {
      onEditPost(post.id, editContent.trim());
    }
    setShowEditModal(false);
  };

  const handleShare = () => {
    navigator.clipboard?.writeText(window.location.href);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  };

  const formatCount = (count: number) => {
    if (count >= 1000000) return `${(count / 1000000).toFixed(1)}M`;
    if (count >= 1000) return `${(count / 1000).toFixed(1)}k`;
    return count.toString();
  };

  const timeAgo = (dateStr: string) => {
    const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
    if (diff < 60) return 'Just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return `${Math.floor(diff / 86400)}d ago`;
  };

  // Sentiment ratio: Check if high civic pushback
  const totalReactions = post.likeCount + post.dislikeCount;
  const dislikeRatio = totalReactions > 0 ? (post.dislikeCount / totalReactions) * 100 : 0;
  const isHighDislike = totalReactions >= 10 && dislikeRatio >= 50;

  return (
    <article className="bg-[#121B2E] rounded-2xl border border-[#27354F] shadow-lg overflow-hidden transition-all hover:border-slate-600/60">
      {/* Top Header */}
      <div className="p-4 sm:p-5 flex items-start justify-between gap-3">
        <div className="flex items-center gap-3 min-w-0">
          {/* Party Logo / Author Avatar */}
          <button
            onClick={() => party && onPartyClick?.(party.id)}
            disabled={!party}
            className="w-11 h-11 rounded-xl bg-[#1B2539] border border-[#27354F] flex items-center justify-center text-2xl hover:scale-105 transition-transform shrink-0 disabled:hover:scale-100"
            title={party?.name || post.authorName || 'Citizen'}
          >
            {party?.logoEmoji || post.imageEmoji || '👤'}
          </button>

          <div className="min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <button
                onClick={() => party && onPartyClick?.(party.id)}
                disabled={!party}
                className="font-display font-semibold text-sm sm:text-base text-white hover:text-[#FF7A2F] transition-colors truncate disabled:hover:text-white"
              >
                {party?.name || post.authorName || 'Citizen Voice (Janta)'}
              </button>
              {party ? (
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#E8697A]/15 text-[#E8697A] border border-[#E8697A]/30">
                  {party.shortName}
                </span>
              ) : (
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#FF7A2F]/15 text-[#FF7A2F] border border-[#FF7A2F]/30">
                  👥 Janta
                </span>
              )}
            </div>

            <div className="flex items-center gap-2 text-xs text-slate-400 mt-0.5 flex-wrap">
              <span>{timeAgo(post.createdAt)}</span>

              {/* Tag for Member-Tagged or Hyper-Local */}
              {post.type === 'memberTagged' && (
                <span className="inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded bg-[#E8AE33]/15 text-[#E8AE33] border border-[#E8AE33]/30">
                  👥 Members Consultation
                </span>
              )}

              {post.channelType === 'hyperLocal' && (
                <span className="inline-flex items-center gap-1 text-[11px] font-semibold px-2 py-0.5 rounded bg-[#3FBFB4]/15 text-[#3FBFB4] border border-[#3FBFB4]/30">
                  <MapPin size={10} />
                  {post.communityId || 'Hyper-Local Ward'}
                </span>
              )}

              {/* Edit History Tag */}
              {post.editHistory && post.editHistory.length > 0 && (
                <button
                  onClick={() => setShowHistoryModal(true)}
                  className="inline-flex items-center gap-0.5 text-[11px] text-[#FF7A2F] font-semibold hover:underline"
                >
                  <History size={11} />
                  <span>(Edited)</span>
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Right Author Actions */}
        <div className="flex items-center gap-1">
          {canEdit && (
            <button
              onClick={() => {
                setEditContent(post.content);
                setShowEditModal(true);
              }}
              className="p-2 rounded-lg text-slate-400 hover:text-white hover:bg-white/5 transition-colors"
              title="Edit Post"
            >
              <Edit3 size={15} />
            </button>
          )}
        </div>
      </div>

      {/* Media Banner if emoji image present */}
      {post.imageEmoji && (
        <div className="bg-[#101D36] py-8 flex items-center justify-center border-y border-[#27354F]/60">
          <span className="text-6xl sm:text-7xl select-none filter drop-shadow-md">
            {post.imageEmoji}
          </span>
        </div>
      )}

      {/* Main Content Body */}
      <div className="px-5 py-3">
        {post.authorName && post.type === 'memberPost' && (
          <div className="mb-2 text-xs font-semibold text-[#E8AE33] flex items-center gap-1.5">
            <span>Posted by</span>
            <span className="text-white underline">{post.authorName}</span>
          </div>
        )}
        <p
          onClick={() => onOpenPost?.(post.id)}
          className={`text-slate-100 text-sm sm:text-base leading-relaxed whitespace-pre-line break-words font-normal ${onOpenPost ? 'cursor-pointer' : ''}`}
        >
          {post.content}
        </p>
        {onOpenPost && (
          <button
            onClick={() => onOpenPost(post.id)}
            className="mt-2 text-[11px] font-semibold text-slate-500 hover:text-[#FF7A2F] transition-colors"
          >
            Open post & discussion →
          </button>
        )}
      </div>

      {/* Community Fact-Check / Disputed Banner */}
      {post.factCheckStatus && post.factCheckStatus !== 'none' && (
        <div className="mx-5 mb-3 p-3.5 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-200 text-xs">
          <div className="flex items-start gap-2.5">
            <AlertTriangle size={16} className="text-amber-400 shrink-0 mt-0.5" />
            <div>
              <div className="flex items-center gap-2 mb-1">
                <span className="font-bold uppercase tracking-wider text-[11px] text-amber-300">
                  {post.factCheckStatus === 'under_review' ? 'Civic Context Added' : 'Fact Check Notice'}
                </span>
                {isHighDislike && (
                  <span className="text-[10px] bg-red-500/20 text-red-300 px-1.5 py-0.5 rounded border border-red-500/30">
                    High Dislike Ratio ({dislikeRatio.toFixed(0)}%)
                  </span>
                )}
              </div>
              <p className="text-slate-300 leading-normal">
                {post.factCheckContext || 'Readers added context they thought people might want to know regarding this claim.'}
              </p>
              {post.factCheckSources && post.factCheckSources.length > 0 && (
                <div className="mt-2 flex flex-wrap gap-2">
                  {post.factCheckSources.map((source, idx) => (
                    <a
                      key={idx}
                      href={source}
                      target="_blank"
                      rel="noreferrer"
                      className="inline-flex items-center gap-1 text-[11px] text-[#FF7A2F] hover:underline bg-black/20 px-2 py-0.5 rounded"
                    >
                      <ExternalLink size={10} />
                      <span>Source {idx + 1}</span>
                    </a>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Action Buttons Row */}
      <div className="px-4 py-2 border-t border-[#27354F] bg-[#101A2E]/50 flex items-center justify-between gap-1 flex-wrap">
        {/* Like Button */}
        <button
          onClick={() => canLike && onReact(post.id, 'like')}
          disabled={!canLike}
          className={`flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-semibold transition-all ${
            post.interaction === 'like'
              ? 'bg-[#21B579]/20 text-[#21B579] border border-[#21B579]/40'
              : 'text-slate-300 hover:text-white hover:bg-white/5'
          } ${!canLike ? 'opacity-50 cursor-not-allowed' : 'active:scale-95'}`}
          title={canLike ? 'Like' : 'Only citizens & party members can interact'}
        >
          <ThumbsUp size={16} className={post.interaction === 'like' ? 'fill-current' : ''} />
          <span>{formatCount(post.likeCount)}</span>
        </button>

        {/* Dislike Button (Democratic civic accountability) */}
        <button
          onClick={() => canLike && onReact(post.id, 'dislike')}
          disabled={!canLike}
          className={`flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-semibold transition-all ${
            post.interaction === 'dislike'
              ? 'bg-[#E63946]/20 text-[#E63946] border border-[#E63946]/40'
              : 'text-slate-300 hover:text-white hover:bg-white/5'
          } ${!canLike ? 'opacity-50 cursor-not-allowed' : 'active:scale-95'}`}
          title={canLike ? 'Dislike' : 'Only citizens & party members can interact'}
        >
          <ThumbsDown size={16} className={post.interaction === 'dislike' ? 'fill-current' : ''} />
          <span>{formatCount(post.dislikeCount)}</span>
        </button>

        {/* Comments Toggle – opens full reading view when available */}
        <button
          onClick={() => (onOpenPost ? onOpenPost(post.id) : setShowComments(!showComments))}
          className={`flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-semibold transition-all ${
            showComments && !onOpenPost
              ? 'bg-[#FF7A2F]/15 text-[#FF7A2F] border border-[#FF7A2F]/40'
              : 'text-slate-300 hover:text-white hover:bg-white/5'
          }`}
          title="Read post & discussion"
        >
          <MessageSquare size={16} />
          <span>{comments.length || post.commentCount}</span>
        </button>

        {/* Share Button */}
        <button
          onClick={handleShare}
          className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold text-slate-300 hover:text-white hover:bg-white/5 transition-all active:scale-95"
        >
          <Share2 size={16} />
          <span>{copiedLink ? 'Copied!' : 'Share'}</span>
        </button>

        {/* Fact-Check / Add Context Button */}
        {onSubmitFactCheck && (
          <button
            onClick={() => setShowFactCheckModal(true)}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold text-[#4FC3F7] hover:bg-[#4FC3F7]/10 border border-[#4FC3F7]/30 transition-all active:scale-95"
            title="Submit verifiable civic context or fact-check note"
          >
            <FileText size={15} />
            <span>Add Context</span>
          </button>
        )}
      </div>

      {/* Permission Restriction Callout (if role cannot interact) */}
      {!canLike && isPartyOfficial && (
        <div className="px-5 py-2 bg-[#0D1626] border-t border-[#27354F] text-[11px] text-slate-400 flex items-center gap-2">
          <Lock size={12} className="text-slate-400" />
          <span>Parties post as official broadcasting entities and cannot cast likes/dislikes.</span>
        </div>
      )}

      {!canLike && isPartyMember && post.type !== 'memberTagged' && !isOwnParty && (
        <div className="px-5 py-2 bg-[#0D1626] border-t border-[#27354F] text-[11px] text-slate-400 flex items-center gap-2">
          <Lock size={12} className="text-slate-400" />
          <span>Party members can interact with their own party or designated consultation posts.</span>
        </div>
      )}

      {/* Comments Section */}
      {showComments && (
        <div className="border-t border-[#27354F] bg-[#0E1728] p-4 sm:p-5 space-y-4">
          <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center justify-between">
            <span>Community Discussion ({comments.length})</span>
            {currentUser.role === 'janta' && currentUser.isAnonymous && (
              <span className="text-[11px] text-[#3FBFB4] font-medium lowercase">
                🔒 Posting as Anonymous Citizen
              </span>
            )}
          </h4>

          {/* Add Comment Input Form */}
          {canComment ? (
            <form onSubmit={handleSendComment} className="flex gap-2.5 items-start">
              <UserAvatar user={currentUser} size="sm" />
              <div className="flex-1 flex gap-2">
                <input
                  type="text"
                  value={commentText}
                  onChange={(e) => setCommentText(e.target.value)}
                  placeholder={
                    currentUser.role === 'janta' && currentUser.isAnonymous
                      ? 'Add your civic view (name hidden)...'
                      : 'Add your civic comment...'
                  }
                  className="flex-1 bg-[#121B2E] border border-[#27354F] rounded-xl px-3.5 py-2 text-xs sm:text-sm text-white placeholder-slate-500 focus:outline-none focus:border-[#FF7A2F] transition-colors"
                />
                <button
                  type="submit"
                  disabled={!commentText.trim()}
                  className="px-3.5 py-2 bg-[#FF7A2F] text-white rounded-xl text-xs font-bold hover:bg-[#E86A24] disabled:opacity-40 disabled:cursor-not-allowed transition-all flex items-center justify-center shrink-0"
                >
                  <Send size={14} />
                </button>
              </div>
            </form>
          ) : (
            <div className="p-3 bg-[#121B2E] rounded-xl border border-[#27354F] text-xs text-slate-400 text-center">
              Commenting on this post is restricted to Citizens and verified party members.
            </div>
          )}

          {/* Comments List */}
          <div className="space-y-3 pt-2">
            {comments.length === 0 ? (
              <p className="text-xs text-slate-500 text-center py-4">
                No comments yet. Start the civic dialogue!
              </p>
            ) : (
              comments.map((comment) => (
                <div
                  key={comment.id}
                  className="flex items-start gap-2.5 p-3 rounded-xl bg-[#121B2E]/60 border border-[#27354F]/50"
                >
                  <UserAvatar
                    user={{
                      displayName: comment.authorName,
                      avatarColor: comment.authorAvatarColor,
                    }}
                    size="sm"
                  />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      <span className="text-xs font-bold text-white">
                        {comment.authorName}
                      </span>
                      <RoleBadge role={comment.authorRole} small />
                      {comment.authorPartyTag && (
                        <PartyTagBadge tag={comment.authorPartyTag} small />
                      )}
                      {comment.authorPartyRole && (
                        <RoleTierBadge role={comment.authorPartyRole} small />
                      )}
                      <span className="text-[10px] text-slate-500 ml-auto">
                        {timeAgo(comment.createdAt)}
                      </span>
                    </div>
                    <p className="text-xs sm:text-sm text-slate-200 leading-relaxed break-words">
                      {comment.content}
                    </p>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {showEditModal && (
        <div
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setShowEditModal(false)}
        >
          <div className="bg-[#121B2E] w-full max-w-lg rounded-2xl border border-[#27354F] shadow-2xl p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-base font-bold text-white font-display">
                Edit Post
              </h3>
              <button
                onClick={() => setShowEditModal(false)}
                className="text-slate-400 hover:text-white"
              >
                <X size={18} />
              </button>
            </div>
            <p className="text-xs text-slate-400 mb-3">
              Edits preserve transparency by appending to public version history.
            </p>
            <textarea
              rows={4}
              value={editContent}
              onChange={(e) => setEditContent(e.target.value)}
              className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl p-3.5 text-sm text-white focus:outline-none focus:border-[#FF7A2F]"
            />
            <div className="flex justify-end gap-2.5 mt-4">
              <button
                onClick={() => setShowEditModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-300 hover:bg-white/5"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveEdit}
                className="px-5 py-2 rounded-xl bg-[#FF7A2F] text-white text-xs font-bold hover:bg-[#E86A24]"
              >
                Save Edit
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit History Modal */}
      {showHistoryModal && (
        <div
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setShowHistoryModal(false)}
        >
          <div className="bg-[#121B2E] w-full max-w-md rounded-2xl border border-[#27354F] shadow-2xl p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <History size={16} className="text-[#FF7A2F]" />
                <h3 className="text-base font-bold text-white font-display">
                  Edit History
                </h3>
              </div>
              <button
                onClick={() => setShowHistoryModal(false)}
                className="text-slate-400 hover:text-white"
              >
                <X size={18} />
              </button>
            </div>
            <p className="text-xs text-slate-400 mb-4">
              Polyticks maintains an immutable edit trail to maintain political accountability.
            </p>
            <div className="space-y-3 max-h-60 overflow-y-auto pr-1">
              <div className="p-3 rounded-xl bg-[#1B2539] border border-[#21B579]/40">
                <span className="text-[10px] uppercase font-bold text-[#21B579]">
                  Current Active Version
                </span>
                <p className="text-xs text-slate-200 mt-1">{post.content}</p>
              </div>

              {post.editHistory?.map((hist, idx) => (
                <div
                  key={idx}
                  className="p-3 rounded-xl bg-[#0B1220] border border-[#27354F]"
                >
                  <span className="text-[10px] uppercase font-bold text-slate-500">
                    Previous Revision #{idx + 1}
                  </span>
                  <p className="text-xs text-slate-400 mt-1 line-through">{hist}</p>
                </div>
              ))}
            </div>
            <button
              onClick={() => setShowHistoryModal(false)}
              className="w-full mt-4 py-2 bg-[#1B2539] hover:bg-[#27354F] text-white rounded-xl text-xs font-semibold"
            >
              Close
            </button>
          </div>
        </div>
      )}

      {/* Community Fact-Check Modal */}
      {showFactCheckModal && onSubmitFactCheck && (
        <SubmitFactCheckModal
          post={post}
          currentUser={currentUser}
          onClose={() => setShowFactCheckModal(false)}
          onSubmit={(postId, contextNote, sources) => {
            onSubmitFactCheck(postId, contextNote, sources);
            setShowFactCheckModal(false);
          }}
        />
      )}
    </article>
  );
};
