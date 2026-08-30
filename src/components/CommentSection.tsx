import React, { useState, useMemo } from 'react';
import { Comment, InteractionType } from '../types';
import { UserAvatar } from './UserAvatar';
import { RoleBadge } from './RoleBadge';
import { PartyTagBadge, RoleTierBadge } from './PartyBadges';
import {
  ThumbsUp,
  ThumbsDown,
  MessageSquare,
  Flag,
  ChevronDown,
  ChevronUp,
  Send
} from 'lucide-react';

export interface CommentNode {
  comment: Comment;
  children: CommentNode[];
}

/** Build a reply tree from the flat comment list. Unlimited data depth. */
export function buildCommentTree(comments: Comment[]): CommentNode[] {
  const byParent = new Map<string | undefined, Comment[]>();
  for (const c of comments) {
    const key = c.parentId ?? undefined;
    if (!byParent.has(key)) byParent.set(key, []);
    byParent.get(key)!.push(c);
  }
  const build = (parentId: string | undefined): CommentNode[] =>
    (byParent.get(parentId) || []).map((comment) => ({
      comment,
      children: build(comment.id),
    }));
  return build(undefined);
}

interface CommentSectionProps {
  postId: string;
  comments: Comment[];
  currentUserRoleCanInteract: boolean;
  currentUserName: string;
  currentUserAvatarColor: string;
  onAddComment: (postId: string, content: string, parentId?: string) => void;
  onReactComment: (commentId: string, reaction: InteractionType) => void;
  onReportComment: (commentId: string, reason: string) => void;
}

const MAX_INDENT = 5;

export const CommentSection: React.FC<CommentSectionProps> = ({
  postId,
  comments,
  currentUserRoleCanInteract,
  currentUserName,
  currentUserAvatarColor,
  onAddComment,
  onReactComment,
  onReportComment,
}) => {
  const tree = useMemo(() => buildCommentTree(comments), [comments]);
  const totalReplies = comments.filter((c) => c.parentId).length;

  return (
    <section className="mt-10">
      <h2 className="text-sm font-semibold text-white tracking-tight mb-5 flex items-center gap-2">
        <MessageSquare size={15} className="text-slate-400" />
        <span>
          Discussion <span className="text-slate-500 font-normal">({comments.length})</span>
        </span>
        {totalReplies > 0 && (
          <span className="text-xs text-slate-500 font-normal">· {totalReplies} replies</span>
        )}
      </h2>

      {/* Top-level composer */}
      {currentUserRoleCanInteract ? (
        <Composer
          postId={postId}
          placeholder="Share your perspective…"
          currentUserName={currentUserName}
          currentUserAvatarColor={currentUserAvatarColor}
          onSubmit={(content) => onAddComment(postId, content)}
        />
      ) : (
        <p className="text-xs text-slate-500 border-l-2 border-[#33415C] pl-3 py-1 mb-6">
          Commenting is available to citizens and verified party members.
        </p>
      )}

      {/* Threads */}
      <div className="space-y-1 mt-6">
        {tree.length === 0 ? (
          <p className="text-sm text-slate-500 py-8 text-center">
            No comments yet. Start the conversation.
          </p>
        ) : (
          tree.map((node) => (
            <CommentItem
              key={node.comment.id}
              node={node}
              depth={0}
              postId={postId}
              currentUserRoleCanInteract={currentUserRoleCanInteract}
              currentUserName={currentUserName}
              currentUserAvatarColor={currentUserAvatarColor}
              onAddComment={onAddComment}
              onReactComment={onReactComment}
              onReportComment={onReportComment}
            />
          ))
        )}
      </div>
    </section>
  );
};

// ── Composer ──

interface ComposerProps {
  postId: string;
  placeholder: string;
  currentUserName: string;
  currentUserAvatarColor: string;
  autoFocus?: boolean;
  compact?: boolean;
  onSubmit: (content: string) => void;
  onCancel?: () => void;
}

const Composer: React.FC<ComposerProps> = ({
  placeholder,
  currentUserName,
  currentUserAvatarColor,
  autoFocus,
  compact,
  onSubmit,
  onCancel,
}) => {
  const [text, setText] = useState('');
  const submit = () => {
    if (!text.trim()) return;
    onSubmit(text.trim());
    setText('');
    onCancel?.();
  };
  return (
    <div className={`flex gap-3 ${compact ? 'mt-3' : 'mb-2'}`}>
      <UserAvatar
        user={{ displayName: currentUserName, avatarColor: currentUserAvatarColor }}
        size="sm"
      />
      <div className="flex-1 flex gap-2 items-start">
        <textarea
          rows={compact ? 2 : 1}
          value={text}
          autoFocus={autoFocus}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              submit();
            }
          }}
          placeholder={placeholder}
          className="flex-1 bg-[#0F1928] border border-[#27354F] rounded-xl px-3.5 py-2.5 text-sm text-slate-100 placeholder-slate-600 focus:outline-none focus:border-[#FF7A2F]/60 resize-none transition-colors"
        />
        <div className="flex flex-col gap-1.5">
          <button
            onClick={submit}
            disabled={!text.trim()}
            aria-label="Submit comment"
            className="px-3 py-2 rounded-xl bg-[#FF7A2F]/90 hover:bg-[#FF7A2F] disabled:opacity-40 text-white transition-colors"
          >
            <Send size={14} />
          </button>
          {onCancel && (
            <button
              onClick={onCancel}
              aria-label="Cancel reply"
              className="px-3 py-2 rounded-xl text-slate-500 hover:text-slate-300 transition-colors"
            >
              <ChevronDown size={14} />
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

// ── Single comment node (recursive) ──

interface CommentItemProps {
  node: CommentNode;
  depth: number;
  postId: string;
  currentUserRoleCanInteract: boolean;
  currentUserName: string;
  currentUserAvatarColor: string;
  onAddComment: (postId: string, content: string, parentId?: string) => void;
  onReactComment: (commentId: string, reaction: InteractionType) => void;
  onReportComment: (commentId: string, reason: string) => void;
}

const CommentItem: React.FC<CommentItemProps> = ({
  node,
  depth,
  postId,
  currentUserRoleCanInteract,
  currentUserName,
  currentUserAvatarColor,
  onAddComment,
  onReactComment,
  onReportComment,
}) => {
  const { comment, children } = node;
  const [replying, setReplying] = useState(false);
  const [collapsed, setCollapsed] = useState(false);
  const [reporting, setReporting] = useState(false);
  const [reportReason, setReportReason] = useState('');

  const hasChildren = children.length > 0;
  const countReplies = (n: CommentNode): number =>
    n.children.reduce((acc, child) => acc + 1 + countReplies(child), 0);

  return (
    <div>
      <div
        className={`py-3 ${depth > 0 ? 'border-l border-[#202C44] ml-3 pl-4' : ''}`}
      >
        <div className="flex gap-3">
          <UserAvatar
            user={{ displayName: comment.authorName, avatarColor: comment.authorAvatarColor }}
            size="sm"
          />
          <div className="flex-1 min-w-0">
            {/* Header */}
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-[13px] font-semibold text-slate-100">{comment.authorName}</span>
              <RoleBadge role={comment.authorRole} small />
              {comment.authorPartyTag && <PartyTagBadge tag={comment.authorPartyTag} small />}
              {comment.authorPartyRole && <RoleTierBadge role={comment.authorPartyRole} small />}
              <span className="text-[11px] text-slate-600">{timeAgo(comment.createdAt)}</span>

              {hasChildren && (
                <button
                  onClick={() => setCollapsed(!collapsed)}
                  className="ml-auto inline-flex items-center gap-1 text-[11px] text-slate-500 hover:text-slate-300 transition-colors"
                  aria-expanded={!collapsed}
                >
                  {collapsed ? <ChevronDown size={12} /> : <ChevronUp size={12} />}
                  <span>{collapsed ? `${countReplies(node)} repl${countReplies(node) === 1 ? 'y' : 'ies'}` : 'Collapse'}</span>
                </button>
              )}
            </div>

            {/* Content */}
            {!collapsed && (
              <p className="text-sm text-slate-300 leading-relaxed mt-1 break-words whitespace-pre-line">
                {comment.content}
              </p>
            )}

            {/* Actions */}
            {!collapsed && (
              <div className="flex items-center gap-4 mt-2">
                <button
                  onClick={() => onReactComment(comment.id, 'like')}
                  disabled={!currentUserRoleCanInteract}
                  className={`inline-flex items-center gap-1.5 text-[11px] font-medium transition-colors ${
                    comment.userInteraction === 'like'
                      ? 'text-emerald-400'
                      : 'text-slate-500 hover:text-slate-300'
                  } ${!currentUserRoleCanInteract ? 'opacity-40 cursor-not-allowed' : ''}`}
                >
                  <ThumbsUp size={12} className={comment.userInteraction === 'like' ? 'fill-current' : ''} />
                  <span>{comment.likeCount}</span>
                </button>

                <button
                  onClick={() => onReactComment(comment.id, 'dislike')}
                  disabled={!currentUserRoleCanInteract}
                  className={`inline-flex items-center gap-1.5 text-[11px] font-medium transition-colors ${
                    comment.userInteraction === 'dislike'
                      ? 'text-red-400'
                      : 'text-slate-500 hover:text-slate-300'
                  } ${!currentUserRoleCanInteract ? 'opacity-40 cursor-not-allowed' : ''}`}
                >
                  <ThumbsDown size={12} className={comment.userInteraction === 'dislike' ? 'fill-current' : ''} />
                  <span>{comment.dislikeCount}</span>
                </button>

                {currentUserRoleCanInteract && (
                  <button
                    onClick={() => setReplying(!replying)}
                    className="text-[11px] font-medium text-slate-500 hover:text-slate-300 transition-colors"
                  >
                    Reply
                  </button>
                )}

                <button
                  onClick={() => setReporting(!reporting)}
                  className="inline-flex items-center gap-1 text-[11px] font-medium text-slate-600 hover:text-amber-400 transition-colors"
                >
                  <Flag size={11} />
                  Report
                </button>
              </div>
            )}

            {/* Inline report form */}
            {reporting && !collapsed && (
              <div className="mt-2.5 flex gap-2 items-center max-w-md">
                <input
                  value={reportReason}
                  onChange={(e) => setReportReason(e.target.value)}
                  placeholder="Why are you reporting this comment?"
                  className="flex-1 bg-[#0F1928] border border-[#27354F] rounded-lg px-3 py-1.5 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-amber-400/50"
                />
                <button
                  onClick={() => {
                    if (reportReason.trim()) {
                      onReportComment(comment.id, reportReason.trim());
                      setReporting(false);
                      setReportReason('');
                    }
                  }}
                  disabled={!reportReason.trim()}
                  className="px-3 py-1.5 rounded-lg bg-amber-400/15 text-amber-300 text-[11px] font-semibold hover:bg-amber-400/25 disabled:opacity-40 transition-colors"
                >
                  Submit
                </button>
                <button
                  onClick={() => setReporting(false)}
                  className="text-[11px] text-slate-500 hover:text-slate-300"
                >
                  Cancel
                </button>
              </div>
            )}

            {/* Inline reply composer */}
            {replying && !collapsed && currentUserRoleCanInteract && (
              <Composer
                compact
                autoFocus
                postId={postId}
                placeholder={`Reply to ${comment.authorName}…`}
                currentUserName={currentUserName}
                currentUserAvatarColor={currentUserAvatarColor}
                onSubmit={(content) => onAddComment(postId, content, comment.id)}
                onCancel={() => setReplying(false)}
              />
            )}
          </div>
        </div>
      </div>

      {/* Nested replies – visual indent capped at MAX_INDENT levels */}
      {!collapsed && hasChildren && (
        <div className={depth < MAX_INDENT - 1 ? 'ml-7' : ''}>
          {children.map((child) => (
            <CommentItem
              key={child.comment.id}
              node={child}
              depth={depth + 1}
              postId={postId}
              currentUserRoleCanInteract={currentUserRoleCanInteract}
              currentUserName={currentUserName}
              currentUserAvatarColor={currentUserAvatarColor}
              onAddComment={onAddComment}
              onReactComment={onReactComment}
              onReportComment={onReportComment}
            />
          ))}
        </div>
      )}
    </div>
  );
};

function timeAgo(dateStr: string): string {
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}
