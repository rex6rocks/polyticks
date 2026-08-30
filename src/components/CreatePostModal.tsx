import React, { useState } from 'react';
import { AppUser, Party, PostType, ChannelType } from '../types';
import { X, Send, MapPin, Globe, Lock, ShieldCheck, User } from 'lucide-react';

interface CreatePostModalProps {
  currentUser: AppUser;
  parties: Party[];
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: {
    partyId: string;
    content: string;
    imageEmoji?: string;
    type: PostType;
    channelType: ChannelType;
    communityId?: string;
    authorId?: string;
    authorName?: string;
  }) => void;
}

const EMOJI_OPTIONS = ['🏥', '🛡️', '🚰', '📜', '🛣️', '📢', '💡', '🌳', '⚖️', '🎓', '🌾', '🚆', '🎉'];

export const CreatePostModal: React.FC<CreatePostModalProps> = ({
  currentUser,
  parties,
  isOpen,
  onClose,
  onSubmit,
}) => {
  const [content, setContent] = useState('');
  const [selectedEmoji, setSelectedEmoji] = useState<string | undefined>('📢');
  const [postType, setPostType] = useState<PostType>('standard');
  const [channelType, setChannelType] = useState<ChannelType>('broader');
  const [communityName, setCommunityName] = useState(currentUser.communityId || 'Indiranagar Ward #84');

  if (!isOpen) return null;

  // Determine user party (if any)
  const userParty = currentUser.partyId ? parties.find((p) => p.id === currentUser.partyId) : undefined;

  // Derive fixed partyId based on user role:
  // - Janta: strictly 'janta'
  // - Party Member / Party: strictly currentUser.partyId
  const effectivePartyId = currentUser.role === 'janta' ? 'janta' : (currentUser.partyId || 'janta');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim()) return;

    onSubmit({
      partyId: effectivePartyId,
      content: content.trim(),
      imageEmoji: selectedEmoji,
      type: currentUser.role === 'partyMember' ? 'memberPost' : postType,
      channelType,
      communityId: channelType === 'hyperLocal' ? communityName : undefined,
      authorId: currentUser.id,
      authorName: currentUser.displayName,
    });

    setContent('');
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4 overflow-hidden">
      <div className="bg-[#121B2E] w-full max-w-xl max-h-[90vh] sm:max-h-[85vh] rounded-t-3xl sm:rounded-3xl border border-[#27354F] shadow-2xl flex flex-col overflow-hidden animate-in fade-in slide-in-from-bottom-5 sm:zoom-in-95 duration-200">
        {/* Header (Sticky at Top) */}
        <div className="p-4 sm:p-5 border-b border-[#27354F] flex items-center justify-between shrink-0 bg-[#121B2E] z-10">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-[#FF7A2F]/20 text-[#FF7A2F] flex items-center justify-center font-bold">
              ✍️
            </div>
            <div>
              <h3 className="font-display font-bold text-base text-white">
                Create Civic Post
              </h3>
            </div>
          </div>
          <button
            onClick={onClose}
            type="button"
            className="p-2 rounded-xl bg-white/5 text-slate-400 hover:text-white hover:bg-white/10 transition-colors shrink-0"
            title="Close modal"
          >
            <X size={20} />
          </button>
        </div>

        {/* Form Body (Scrollable Content Area) */}
        <form onSubmit={handleSubmit} className="p-4 sm:p-5 space-y-4 overflow-y-auto flex-1 custom-scrollbar">
          {/* Representation Indicator (STRICT ROLE ENFORCEMENT - NO SELECTOR ALLOWED) */}
          {currentUser.role === 'janta' && (
            <div className="p-3.5 rounded-2xl bg-[#FF7A2F]/10 border border-[#FF7A2F]/30 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-[#FF7A2F] text-black flex items-center justify-center font-bold shrink-0">
                  <User size={18} />
                </div>
                <div>
                  <p className="text-xs font-bold text-white">Posting as Citizen (Janta)</p>
                  <p className="text-[11px] text-[#FF7A2F]">Individual citizen voice</p>
                </div>
              </div>
              <Lock size={16} className="text-[#FF7A2F] shrink-0" />
            </div>
          )}

          {currentUser.role === 'partyMember' && (
            <div className="p-3.5 rounded-2xl bg-[#E8AE33]/10 border border-[#E8AE33]/30 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <span className="text-2xl shrink-0">{userParty?.logoEmoji || '👥'}</span>
                <div>
                  <p className="text-xs font-bold text-white">
                    Representing: {userParty?.name || 'Your Party'}
                  </p>
                  <p className="text-[11px] text-[#E8AE33]">
                    Affiliated Party Member
                  </p>
                </div>
              </div>
              <Lock size={16} className="text-[#E8AE33] shrink-0" />
            </div>
          )}

          {currentUser.role === 'party' && (
            <div className="p-3.5 rounded-2xl bg-[#3FBFB4]/10 border border-[#3FBFB4]/30 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <span className="text-2xl shrink-0">{userParty?.logoEmoji || '🏛️'}</span>
                <div>
                  <p className="text-xs font-bold text-white">
                    Posting as {userParty?.name || currentUser.displayName}
                  </p>
                  <p className="text-[11px] text-[#3FBFB4]">
                    Official Political Party Account — Verified entity channel
                  </p>
                </div>
              </div>
              <ShieldCheck size={18} className="text-[#3FBFB4] shrink-0" />
            </div>
          )}

          {/* Scope / Channel Selector */}
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              Broadcast Scope:
            </label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setChannelType('broader')}
                className={`p-2.5 rounded-xl border flex items-center justify-center gap-2 text-xs font-semibold transition-all ${
                  channelType === 'broader'
                    ? 'bg-[#FF7A2F] text-white border-[#FF7A2F]'
                    : 'bg-[#1B2539] border-[#33415C] text-slate-300 hover:bg-white/5'
                }`}
              >
                <Globe size={15} />
                <span>Broader / National</span>
              </button>

              <button
                type="button"
                onClick={() => setChannelType('hyperLocal')}
                className={`p-2.5 rounded-xl border flex items-center justify-center gap-2 text-xs font-semibold transition-all ${
                  channelType === 'hyperLocal'
                    ? 'bg-[#3FBFB4] text-[#0B1220] border-[#3FBFB4] font-bold'
                    : 'bg-[#1B2539] border-[#33415C] text-slate-300 hover:bg-white/5'
                }`}
              >
                <MapPin size={15} />
                <span>Hyper-Local Ward</span>
              </button>
            </div>

            {channelType === 'hyperLocal' && (
              <div className="mt-2">
                <input
                  type="text"
                  value={communityName}
                  onChange={(e) => setCommunityName(e.target.value)}
                  placeholder="Enter Ward / Neighborhood (e.g. Ward #84)"
                  className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl px-3.5 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-[#3FBFB4]"
                />
              </div>
            )}
          </div>

          {/* Post Type Selector (Standard vs Member Tagged Consultation) */}
          {currentUser.role === 'party' && (
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Target Audience:
              </label>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setPostType('standard')}
                  className={`flex-1 py-2 px-3 rounded-xl border text-xs font-medium transition-all ${
                    postType === 'standard'
                      ? 'bg-[#FF7A2F]/20 text-[#FF7A2F] border-[#FF7A2F]'
                      : 'bg-[#1B2539] border-[#33415C] text-slate-400'
                  }`}
                >
                  Public Broadcast
                </button>
                <button
                  type="button"
                  onClick={() => setPostType('memberTagged')}
                  className={`flex-1 py-2 px-3 rounded-xl border text-xs font-medium transition-all ${
                    postType === 'memberTagged'
                      ? 'bg-[#E8AE33]/20 text-[#E8AE33] border-[#E8AE33]'
                      : 'bg-[#1B2539] border-[#33415C] text-slate-400'
                  }`}
                >
                  👥 Member Consultation (Tagged)
                </button>
              </div>
            </div>
          )}

          {/* Post Content */}
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              Content:
            </label>
            <textarea
              rows={4}
              value={content}
              onChange={(e) => setContent(e.target.value)}
              placeholder="What civic update, manifesto point, or policy consultation would you like to share?"
              className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl p-3.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-[#FF7A2F]"
            />
          </div>

          {/* Emoji Graphic Banner */}
          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5 flex items-center justify-between">
              <span>Topic Emoji Graphic:</span>
              {selectedEmoji && (
                <button
                  type="button"
                  onClick={() => setSelectedEmoji(undefined)}
                  className="text-[10px] text-slate-400 hover:text-white"
                >
                  Remove
                </button>
              )}
            </label>
            <div className="flex flex-wrap gap-2">
              {EMOJI_OPTIONS.map((emoji) => (
                <button
                  type="button"
                  key={emoji}
                  onClick={() => setSelectedEmoji(emoji)}
                  className={`w-9 h-9 rounded-xl flex items-center justify-center text-lg transition-all ${
                    selectedEmoji === emoji
                      ? 'bg-[#FF7A2F] text-white scale-110 elevate-sm'
                      : 'bg-[#1B2539] hover:bg-[#33415C] text-slate-300'
                  }`}
                >
                  {emoji}
                </button>
              ))}
            </div>
          </div>

          {/* Footer Actions (Sticky at Bottom) */}
          <div className="sticky bottom-0 bg-[#121B2E] pt-3 pb-2 border-t border-[#27354F] flex items-center justify-end gap-2.5 shrink-0 z-10">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2.5 rounded-xl text-xs font-semibold text-slate-300 hover:bg-white/5"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!content.trim()}
              className="flex items-center gap-2 px-6 py-2.5 rounded-xl bg-gradient-to-r from-[#FF7A2F] to-[#E86A24] text-white text-xs font-bold elevate-sm hover:brightness-110 disabled:opacity-40 disabled:cursor-not-allowed transition-all"
            >
              <Send size={14} />
              <span>Publish Post</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
