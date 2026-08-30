import React, { useState } from 'react';
import { VerificationRequest, Post, ReportEntry } from '../types';
import { PurgeRecord } from '../services/storageService';
import {
  ShieldCheck,
  CheckCircle2,
  XCircle,
  Trash2,
  Eye,
  Lock,
  HardDrive,
  FileCheck,
  X,
  Timer,
  Check,
  Clock,
  Search,
  Flag
} from 'lucide-react';

interface AdminConsoleScreenProps {
  verifications: VerificationRequest[];
  purgeLogs: PurgeRecord[];
  posts: Post[];
  reports: ReportEntry[];
  onApprove: (verId: string) => void;
  onReject: (verId: string) => void;
  onModeratePost?: (postId: string, approveRestore: boolean) => void;
  onResolveReport?: (reportId: string, takeDown: boolean) => void;
}

export const AdminConsoleScreen: React.FC<AdminConsoleScreenProps> = ({
  verifications,
  purgeLogs,
  posts,
  reports,
  onApprove,
  onReject,
  onModeratePost,
  onResolveReport,
}) => {
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [activeSubTab, setActiveSubTab] = useState<'pending' | 'moderation_queue' | 'purge_log'>('pending');
  const [searchQuery, setSearchQuery] = useState('');
  const [urgencyFilter, setUrgencyFilter] = useState<'all' | 'breached' | 'critical' | 'warning' | 'normal'>('all');

  const pendingRequests = verifications.filter((v) => v.status === 'pending');
  const totalPurgedBytes = purgeLogs.reduce((sum, item) => sum + item.bytesFreed, 0);

  // Moderation items from posts
  const flaggedPosts = posts.filter(
    (p) =>
      p.isHidden ||
      (p.factCheckStatus && p.factCheckStatus !== 'none') ||
      p.flaggedReason ||
      p.dislikeCount >= 3
  );

  // Helper to calculate SLA urgency and time remaining (24 hours from creation)
  const getSlaDetails = (createdAt: string) => {
    const createdTime = new Date(createdAt).getTime();
    const deadlineTime = createdTime + 24 * 60 * 60 * 1000;
    const now = Date.now();
    const diffMs = deadlineTime - now;

    if (diffMs < 0) {
      const hoursAgo = Math.abs(Math.floor(diffMs / (1000 * 60 * 60)));
      return {
        level: 'breached' as const,
        label: `Breached (${hoursAgo}h overdue)`,
        color: 'text-red-400 bg-red-500/15 border-red-500/30',
        badge: 'bg-red-500',
      };
    } else if (diffMs < 4 * 60 * 60 * 1000) {
      const hoursLeft = Math.floor(diffMs / (1000 * 60 * 60));
      const minsLeft = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
      return {
        level: 'critical' as const,
        label: `${hoursLeft}h ${minsLeft}m left (Critical)`,
        color: 'text-orange-400 bg-orange-500/15 border-orange-500/30',
        badge: 'bg-orange-500',
      };
    } else if (diffMs < 12 * 60 * 60 * 1000) {
      const hoursLeft = Math.floor(diffMs / (1000 * 60 * 60));
      return {
        level: 'warning' as const,
        label: `${hoursLeft}h left (Warning)`,
        color: 'text-amber-400 bg-amber-500/15 border-amber-500/30',
        badge: 'bg-amber-500',
      };
    } else {
      const hoursLeft = Math.floor(diffMs / (1000 * 60 * 60));
      return {
        level: 'normal' as const,
        label: `${hoursLeft}h left`,
        color: 'text-emerald-400 bg-emerald-500/15 border-emerald-500/30',
        badge: 'bg-emerald-500',
      };
    }
  };

  const filteredFlaggedPosts = flaggedPosts.filter((post) => {
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const match =
        post.content.toLowerCase().includes(q) ||
        (post.authorName && post.authorName.toLowerCase().includes(q)) ||
        (post.flaggedReason && post.flaggedReason.toLowerCase().includes(q));
      if (!match) return false;
    }
    if (urgencyFilter !== 'all') {
      const sla = getSlaDetails(post.createdAt);
      if (sla.level !== urgencyFilter) return false;
    }
    return true;
  });

  return (
    <div className="max-w-5xl mx-auto px-4 py-6 space-y-6">
      {/* Header */}
      <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] p-6 sm:p-8 shadow-xl flex items-start justify-between gap-4 flex-wrap">
        <div>
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#21B579]/15 text-[#21B579] border border-[#21B579]/30 text-xs font-bold mb-2">
            <ShieldCheck size={14} />
            <span>Civic Moderator & Trust Engine Console</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold font-display text-white">
            Civic Moderation & ID Verification
          </h1>
          <p className="text-xs sm:text-sm text-slate-300 max-w-2xl mt-1 leading-relaxed">
            Manage zero-retention voter credentials, monitor disputed content under 24-hour SLA review, and audit automated storage purges.
          </p>
        </div>

        {/* Stats Summary Widget */}
        <div className="flex gap-3">
          <div className="bg-[#1B2539] p-3 rounded-2xl border border-[#27354F] text-center min-w-[100px]">
            <p className="text-xl font-bold font-display text-[#E8AE33]">
              {pendingRequests.length}
            </p>
            <p className="text-[10px] uppercase font-bold text-slate-400">Pending IDs</p>
          </div>

          <div className="bg-[#1B2539] p-3 rounded-2xl border border-[#27354F] text-center min-w-[100px]">
            <p className="text-xl font-bold font-display text-[#FF7043]">
              {flaggedPosts.length}
            </p>
            <p className="text-[10px] uppercase font-bold text-slate-400">SLA Queue</p>
          </div>

          <div className="bg-[#1B2539] p-3 rounded-2xl border border-[#27354F] text-center min-w-[100px]">
            <p className="text-xl font-bold font-display text-[#21B579]">
              {(totalPurgedBytes / 1024).toFixed(1)} KB
            </p>
            <p className="text-[10px] uppercase font-bold text-slate-400">Purged</p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-2 border-b border-[#27354F] pb-2 text-xs font-bold flex-wrap">
        <button
          onClick={() => setActiveSubTab('pending')}
          className={`px-4 py-2 rounded-xl transition-all flex items-center gap-2 ${
            activeSubTab === 'pending'
              ? 'bg-[#21B579] text-white shadow-md shadow-emerald-500/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <FileCheck size={14} />
          <span>Pending ID Verifications ({pendingRequests.length})</span>
        </button>

        <button
          onClick={() => setActiveSubTab('moderation_queue')}
          className={`px-4 py-2 rounded-xl transition-all flex items-center gap-2 ${
            activeSubTab === 'moderation_queue'
              ? 'bg-[#4FC3F7] text-[#0F1B2D] shadow-md shadow-sky-500/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <Timer size={14} />
          <span>24h SLA Moderation Queue ({flaggedPosts.length})</span>
        </button>

        <button
          onClick={() => setActiveSubTab('purge_log')}
          className={`px-4 py-2 rounded-xl transition-all flex items-center gap-2 ${
            activeSubTab === 'purge_log'
              ? 'bg-[#21B579] text-white shadow-md shadow-emerald-500/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <Trash2 size={14} />
          <span>Zero-Retention Audit ({purgeLogs.length})</span>
        </button>
      </div>

      {/* User Reports Queue */}
      {reports.length > 0 && (
        <div className="bg-[#121B2E] rounded-2xl border border-amber-500/30 p-5 space-y-3">
          <div className="flex items-center gap-2">
            <Flag size={15} className="text-amber-400" />
            <h3 className="text-sm font-bold text-white font-display">
              User Reports ({reports.filter((r) => r.status === 'open').length} open)
            </h3>
          </div>
          <div className="space-y-2.5">
            {reports.map((report) => {
              const target = report.targetType === 'post'
                ? posts.find((p) => p.id === report.targetId)?.content
                : undefined;
              return (
                <div
                  key={report.id}
                  className="flex items-start justify-between gap-3 p-3 rounded-xl bg-[#1B2539] border border-[#27354F] flex-wrap"
                >
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2 flex-wrap text-xs">
                      <span className="font-bold text-white">{report.reporterName}</span>
                      <span className="text-slate-500">reported a {report.targetType}</span>
                      <span className={`text-[10px] px-1.5 py-0.5 rounded-full border ${
                        report.status === 'open'
                          ? 'bg-amber-400/10 text-amber-300 border-amber-400/30'
                          : 'bg-emerald-400/10 text-emerald-300 border-emerald-400/30'
                      }`}>
                        {report.status}
                      </span>
                    </div>
                    <p className="text-xs text-slate-300 mt-1">
                      Reason: <span className="text-slate-100">{report.reason}</span>
                    </p>
                    {target && (
                      <p className="text-[11px] text-slate-500 mt-1 truncate">“{target}”</p>
                    )}
                  </div>
                  {report.status === 'open' && onResolveReport && (
                    <div className="flex items-center gap-2 shrink-0">
                      <button
                        onClick={() => onResolveReport(report.id, true)}
                        className="px-3 py-1.5 rounded-lg bg-red-500/15 text-red-400 border border-red-500/30 text-xs font-bold hover:bg-red-500/25 transition-colors flex items-center gap-1"
                      >
                        <Trash2 size={12} /> Take down
                      </button>
                      <button
                        onClick={() => onResolveReport(report.id, false)}
                        className="px-3 py-1.5 rounded-lg bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 text-xs font-bold hover:bg-emerald-500/25 transition-colors flex items-center gap-1"
                      >
                        <Check size={12} /> Dismiss
                      </button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* 24h SLA Moderation Queue Sub-Tab */}
      {activeSubTab === 'moderation_queue' && (
        <div className="space-y-4">
          {/* Filter and Search Bar */}
          <div className="bg-[#121B2E] rounded-2xl border border-[#27354F] p-4 flex flex-col sm:flex-row gap-3 items-center justify-between">
            <div className="relative w-full sm:w-72">
              <Search size={15} className="absolute left-3 top-3 text-slate-500" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search flagged content..."
                className="w-full bg-[#0F1B2D] border border-[#27354F] rounded-xl pl-9 pr-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-[#4FC3F7]"
              />
            </div>

            <div className="flex items-center gap-1.5 overflow-x-auto w-full sm:w-auto">
              {(['all', 'breached', 'critical', 'warning', 'normal'] as const).map((filter) => (
                <button
                  key={filter}
                  onClick={() => setUrgencyFilter(filter)}
                  className={`px-2.5 py-1.5 rounded-lg text-xs font-semibold uppercase tracking-wider transition-all ${
                    urgencyFilter === filter
                      ? 'bg-[#4FC3F7] text-[#0F1B2D]'
                      : 'bg-[#1B2539] text-slate-400 hover:text-white border border-[#27354F]'
                  }`}
                >
                  {filter}
                </button>
              ))}
            </div>
          </div>

          {filteredFlaggedPosts.length === 0 ? (
            <div className="p-12 text-center bg-[#121B2E] rounded-3xl border border-[#27354F]">
              <div className="w-16 h-16 rounded-full bg-[#21B579]/20 text-[#21B579] flex items-center justify-center text-2xl mx-auto mb-3">
                <CheckCircle2 size={32} />
              </div>
              <h3 className="text-base font-bold text-white font-display mb-1">
                Moderation Queue is Clear!
              </h3>
              <p className="text-xs text-slate-400 max-w-sm mx-auto">
                No reported or disputed civic posts currently require moderator resolution.
              </p>
            </div>
          ) : (
            filteredFlaggedPosts.map((post) => {
              const sla = getSlaDetails(post.createdAt);
              const totalVotes = post.likeCount + post.dislikeCount;
              const dislikeRatio = totalVotes > 0 ? (post.dislikeCount / totalVotes) * 100 : 0;

              return (
                <div
                  key={post.id}
                  className="bg-[#121B2E] rounded-2xl border border-[#27354F] p-5 shadow-lg space-y-4"
                >
                  {/* Top Row: SLA status & Post ID */}
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <div className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-lg border text-xs font-bold ${sla.color}`}>
                      <Clock size={13} />
                      <span>SLA: {sla.label}</span>
                    </div>

                    <div className="flex items-center gap-2">
                      {post.isHidden && (
                        <span className="px-2 py-0.5 rounded bg-red-500/20 border border-red-500/30 text-red-300 text-[10px] font-bold uppercase">
                          Auto-Hidden
                        </span>
                      )}
                      <span className="text-xs text-slate-400">Post #{post.id}</span>
                    </div>
                  </div>

                  {/* Flagged Reason / Dispute */}
                  <div className="p-3 rounded-xl bg-[#0F1B2D] border border-amber-500/20 text-xs text-amber-200">
                    <span className="font-bold text-amber-400">Trigger: </span>
                    <span>
                      {post.flaggedReason ||
                        (dislikeRatio > 50
                          ? `Democratic Dislike Trigger (${dislikeRatio.toFixed(0)}% Dislikes)`
                          : 'Civic Context Reported by Citizens')}
                    </span>
                  </div>

                  {/* Content snippet */}
                  <p className="text-sm text-slate-200 leading-relaxed whitespace-pre-line">
                    {post.content}
                  </p>

                  {/* Fact-Check context if attached */}
                  {post.factCheckContext && (
                    <div className="p-3 rounded-xl bg-[#1B2539] border border-[#27354F] text-xs text-sky-200">
                      <span className="font-bold text-[#4FC3F7]">Community Note: </span>
                      <span>{post.factCheckContext}</span>
                    </div>
                  )}

                  {/* Post Stats & Actions */}
                  <div className="pt-2 border-t border-[#27354F] flex items-center justify-between flex-wrap gap-3">
                    <div className="flex items-center gap-4 text-xs text-slate-400">
                      <span>👍 {post.likeCount} Likes</span>
                      <span className="text-red-400">👎 {post.dislikeCount} Dislikes</span>
                      <span>Dislike Ratio: {dislikeRatio.toFixed(0)}%</span>
                    </div>

                    {onModeratePost && (
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => onModeratePost(post.id, false)}
                          className="px-3.5 py-1.5 rounded-xl border border-red-500/40 text-red-400 hover:bg-red-500/10 text-xs font-bold flex items-center gap-1.5 transition-colors"
                        >
                          <Trash2 size={13} />
                          <span>Delete Content</span>
                        </button>
                        <button
                          onClick={() => onModeratePost(post.id, true)}
                          className="px-4 py-1.5 rounded-xl bg-emerald-500 hover:bg-emerald-600 text-white text-xs font-bold flex items-center gap-1.5 transition-colors elevate-sm"
                        >
                          <Check size={13} />
                          <span>Approve & Verify</span>
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}

      {/* Pending Submissions Queue */}
      {activeSubTab === 'pending' && (
        <div className="space-y-4">
          {pendingRequests.length === 0 ? (
            <div className="p-12 text-center bg-[#121B2E] rounded-3xl border border-[#27354F]">
              <div className="w-16 h-16 rounded-full bg-[#21B579]/20 text-[#21B579] flex items-center justify-center text-2xl mx-auto mb-3">
                <CheckCircle2 size={32} />
              </div>
              <h3 className="text-base font-bold text-white font-display mb-1">
                Queue is Clear!
              </h3>
              <p className="text-xs text-slate-400 max-w-sm mx-auto">
                All submitted government IDs have been audited and their storage footprint completely wiped.
              </p>
            </div>
          ) : (
            pendingRequests.map((req) => (
              <div
                key={req.id}
                className="bg-[#121B2E] rounded-2xl border border-[#27354F] p-5 shadow-lg flex flex-col md:flex-row items-start md:items-center justify-between gap-4"
              >
                {/* User & Request Info */}
                <div className="space-y-1.5">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-bold text-white font-display">
                      {req.username}
                    </span>
                    <span className="px-2 py-0.5 rounded-md bg-[#E8AE33]/15 text-[#E8AE33] border border-[#E8AE33]/30 text-[10px] font-bold uppercase">
                      {req.documentType}
                    </span>
                    <span className="text-xs text-slate-400">
                      ({req.fileSizeKb || 120} KB)
                    </span>
                  </div>

                  <p className="text-xs text-slate-300">
                    Phone: <span className="font-mono">{req.phone}</span> • User ID:{' '}
                    <span className="font-mono text-slate-400">{req.userId}</span>
                  </p>

                  <div className="flex items-center gap-1.5 text-[11px] text-[#21B579]">
                    <Lock size={12} />
                    <span>Zero-Retention Policy: Document will be purged from disk immediately upon verdict.</span>
                  </div>
                </div>

                {/* Actions & Image Preview */}
                <div className="flex items-center gap-3 w-full md:w-auto justify-end">
                  <button
                    onClick={() => setSelectedImage(req.imageUrl)}
                    className="px-3 py-2 rounded-xl bg-[#1B2539] hover:bg-[#22385C] border border-[#27354F] text-slate-300 text-xs font-semibold flex items-center gap-1.5 transition-colors"
                  >
                    <Eye size={14} />
                    <span>Inspect Doc</span>
                  </button>

                  <button
                    onClick={() => onReject(req.id)}
                    className="px-3.5 py-2 rounded-xl border border-red-500/30 text-red-400 hover:bg-red-500/10 text-xs font-bold flex items-center gap-1.5 transition-colors"
                  >
                    <XCircle size={14} />
                    <span>Reject & Purge</span>
                  </button>

                  <button
                    onClick={() => onApprove(req.id)}
                    className="px-4 py-2 rounded-xl bg-[#21B579] hover:bg-[#00A86B] text-white text-xs font-bold flex items-center gap-1.5 elevate-sm transition-all active:scale-95"
                  >
                    <CheckCircle2 size={14} />
                    <span>Approve & Purge</span>
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {/* Purge Audit Trail Sub-Tab */}
      {activeSubTab === 'purge_log' && (
        <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] p-6 shadow-xl space-y-4">
          <div className="flex items-center justify-between border-b border-[#27354F] pb-4">
            <div>
              <h3 className="text-sm font-bold text-white font-display">
                Cryptographic Storage Purge Log
              </h3>
              <p className="text-xs text-slate-400">
                Immutable audit entries verifying document destruction immediately after review.
              </p>
            </div>
            <div className="flex items-center gap-1.5 text-xs text-[#21B579] font-bold">
              <HardDrive size={14} />
              <span>{purgeLogs.length} Records Cleared</span>
            </div>
          </div>

          <div className="divide-y divide-[#27354F] max-h-96 overflow-y-auto">
            {purgeLogs.length === 0 ? (
              <p className="py-8 text-center text-xs text-slate-400">
                No purge events recorded yet.
              </p>
            ) : (
              purgeLogs.map((log) => (
                <div key={log.id} className="py-3 flex items-center justify-between text-xs">
                  <div className="flex items-center gap-3">
                    <div
                      className={`w-7 h-7 rounded-lg flex items-center justify-center ${
                        log.action === 'approved'
                          ? 'bg-[#21B579]/15 text-[#21B579]'
                          : 'bg-red-500/15 text-red-400'
                      }`}
                    >
                      <Trash2 size={14} />
                    </div>
                    <div>
                      <p className="font-semibold text-white">
                        {log.username} ({log.userId})
                      </p>
                      <p className="text-[11px] text-slate-400 font-mono">
                        Verdict: {log.action.toUpperCase()} • Purged at {new Date(log.purgedAt).toLocaleTimeString()}
                      </p>
                    </div>
                  </div>

                  <div className="text-right font-mono text-[#21B579] text-[11px]">
                    -{(log.bytesFreed / 1024).toFixed(1)} KB freed
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {/* Document Inspector Modal */}
      {selectedImage && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm">
          <div className="bg-[#121B2E] border border-[#27354F] max-w-lg w-full rounded-3xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-white font-bold font-display text-sm">
                <Lock size={16} className="text-[#21B579]" />
                <span>Ephemerally Decrypted Document</span>
              </div>
              <button
                onClick={() => setSelectedImage(null)}
                className="text-slate-400 hover:text-white"
              >
                <X size={18} />
              </button>
            </div>

            <div className="rounded-2xl overflow-hidden border border-[#27354F] bg-[#0B1220] flex items-center justify-center min-h-[220px]">
              <img
                src={selectedImage}
                alt="Government ID"
                className="max-h-72 object-contain"
                referrerPolicy="no-referrer"
              />
            </div>

            <p className="text-[11px] text-slate-400 leading-relaxed">
              Verifying document authenticity. Closing or rendering a verdict will permanently delete this document image from memory.
            </p>

            <button
              onClick={() => setSelectedImage(null)}
              className="w-full py-2 bg-[#1B2539] hover:bg-[#27354F] text-white text-xs font-semibold rounded-xl transition-colors"
            >
              Close Inspector
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
