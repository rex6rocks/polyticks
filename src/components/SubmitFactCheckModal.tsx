import React, { useState } from 'react';
import { AppUser, Post } from '../types';
import { FileText, Plus, X, Link as LinkIcon, AlertCircle, CheckCircle } from 'lucide-react';

interface SubmitFactCheckModalProps {
  post: Post;
  currentUser: AppUser;
  onClose: () => void;
  onSubmit: (postId: string, contextNote: string, sources: string[]) => void;
}

export const SubmitFactCheckModal: React.FC<SubmitFactCheckModalProps> = ({
  post,
  currentUser,
  onClose,
  onSubmit,
}) => {
  const [contextNote, setContextNote] = useState('');
  const [sourceUrl, setSourceUrl] = useState('');
  const [sources, setSources] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);

  const handleAddSource = () => {
    const trimmed = sourceUrl.trim();
    if (!trimmed) return;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      setError('Source link must start with http:// or https://');
      return;
    }
    if (sources.includes(trimmed)) {
      setError('This source is already added');
      return;
    }
    setSources([...sources, trimmed]);
    setSourceUrl('');
    setError(null);
  };

  const handleRemoveSource = (index: number) => {
    setSources(sources.filter((_, i) => i !== index));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!contextNote.trim()) {
      setError('Context note cannot be empty');
      return;
    }
    if (contextNote.trim().length < 15) {
      setError('Context note should be at least 15 characters to provide verifiable details');
      return;
    }

    const finalSources = [...sources];
    if (sourceUrl.trim() && (sourceUrl.startsWith('http://') || sourceUrl.startsWith('https://'))) {
      if (!finalSources.includes(sourceUrl.trim())) {
        finalSources.push(sourceUrl.trim());
      }
    }

    onSubmit(post.id, contextNote.trim(), finalSources);
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-fadeIn">
      <div className="bg-[#121B2E] border border-[#27354F] w-full max-w-lg rounded-3xl p-6 shadow-2xl space-y-5">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-xl bg-[#4FC3F7]/15 border border-[#4FC3F7]/30 flex items-center justify-center text-[#4FC3F7]">
              <FileText size={20} />
            </div>
            <div>
              <h2 className="text-lg font-bold font-display text-white">
                Add Community Context
              </h2>
              <p className="text-xs text-slate-400">
                Submitting as @{currentUser.displayName} ({currentUser.role})
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-white/5 transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        {/* Post Preview Snippet */}
        <div className="p-3 rounded-xl bg-[#0F1B2D] border border-[#27354F] text-xs text-slate-300 line-clamp-2 italic">
          "{post.content}"
        </div>

        {/* Error message if any */}
        {error && (
          <div className="flex items-center gap-2 p-3 rounded-xl bg-red-500/15 border border-red-500/30 text-red-300 text-xs">
            <AlertCircle size={15} className="shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Note Input */}
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              Factual Context / Neutral Clarification
            </label>
            <textarea
              rows={4}
              value={contextNote}
              onChange={(e) => {
                setContextNote(e.target.value);
                if (error) setError(null);
              }}
              placeholder="Cite neutral facts, official government documents, or public records to provide context for this claim..."
              className="w-full bg-[#0F1B2D] border border-[#27354F] rounded-xl p-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-[#4FC3F7] transition-colors"
            />
          </div>

          {/* Sources Section */}
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              Verifiable Sources & References
            </label>
            <div className="flex gap-2">
              <div className="relative flex-1">
                <LinkIcon size={14} className="absolute left-3 top-3.5 text-slate-500" />
                <input
                  type="url"
                  value={sourceUrl}
                  onChange={(e) => {
                    setSourceUrl(e.target.value);
                    if (error) setError(null);
                  }}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleAddSource();
                    }
                  }}
                  placeholder="https://official-gazette.gov.in/..."
                  className="w-full bg-[#0F1B2D] border border-[#27354F] rounded-xl py-2.5 pl-9 pr-3 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-[#4FC3F7]"
                />
              </div>
              <button
                type="button"
                onClick={handleAddSource}
                className="px-3 py-2 bg-[#1B2539] hover:bg-[#22385C] border border-[#27354F] text-[#4FC3F7] rounded-xl text-xs font-semibold flex items-center gap-1 transition-colors"
              >
                <Plus size={14} />
                <span>Add</span>
              </button>
            </div>

            {/* Source chips */}
            {sources.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-1.5">
                {sources.map((src, idx) => (
                  <span
                    key={idx}
                    className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-[#0F1B2D] border border-[#27354F] text-[11px] text-[#4FC3F7]"
                  >
                    <span className="truncate max-w-[200px]">{src}</span>
                    <button
                      type="button"
                      onClick={() => handleRemoveSource(idx)}
                      className="hover:text-red-400 ml-1"
                    >
                      <X size={12} />
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Action buttons */}
          <div className="flex items-center justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-xs font-semibold text-slate-400 hover:text-white transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-5 py-2.5 bg-[#4FC3F7] hover:bg-[#38B6EC] text-[#0F1B2D] font-bold text-xs rounded-xl shadow-lg shadow-sky-500/20 transition-all active:scale-95 flex items-center gap-1.5"
            >
              <CheckCircle size={15} />
              <span>Publish Context</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
