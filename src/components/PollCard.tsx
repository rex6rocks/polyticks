import React from 'react';
import { Poll, AppUser, Party } from '../types';
import { Vote, Timer, Lock, CheckCircle2 } from 'lucide-react';

interface PollCardProps {
  poll: Poll;
  party?: Party;
  currentUser: AppUser;
  onVote: (pollId: string, optionId: string) => void;
  onPartyClick?: (partyId: string) => void;
}

export const PollCard: React.FC<PollCardProps> = ({
  poll,
  party,
  currentUser,
  onVote,
  onPartyClick,
}) => {
  // Only party members belonging to this party can cast votes in member-exclusive ballots
  const canVote =
    currentUser.role === 'partyMember' && currentUser.partyId === poll.partyId;

  const hasVoted = Boolean(poll.votedOptionId);
  const totalVotes = poll.options.reduce((sum, opt) => sum + opt.votes, 0);

  const timeLeft = () => {
    const diff = new Date(poll.endsAt).getTime() - Date.now();
    if (diff <= 0) return 'Ended';
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    if (days > 0) return `${days}d left`;
    const hours = Math.floor(diff / (1000 * 60 * 60));
    return `${hours}h left`;
  };

  return (
    <div className="bg-[#121B2E] rounded-2xl border border-[#27354F] p-5 shadow-lg relative overflow-hidden">
      {/* Top Header */}
      <div className="flex items-center justify-between gap-2 mb-4">
        <div className="flex items-center gap-2">
          <button
            onClick={() => party && onPartyClick?.(party.id)}
            className="w-8 h-8 rounded-lg bg-[#1B2539] border border-[#27354F] flex items-center justify-center text-base"
          >
            {party?.logoEmoji || '🗳️'}
          </button>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-white">
                {party?.name || 'Party'}
              </span>
              <span className="inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#E8AE33]/15 text-[#E8AE33] border border-[#E8AE33]/30">
                <Vote size={11} />
                Members Ballot
              </span>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-1 text-xs text-slate-400">
          <Timer size={13} />
          <span>{timeLeft()}</span>
        </div>
      </div>

      {/* Poll Question */}
      <h3 className="text-base font-semibold text-white font-display leading-snug mb-4">
        {poll.question}
      </h3>

      {/* Options List */}
      <div className="space-y-2.5">
        {poll.options.map((option) => {
          const isSelected = poll.votedOptionId === option.id;
          const percentage =
            totalVotes > 0 ? Math.round((option.votes / totalVotes) * 100) : 0;

          return (
            <button
              key={option.id}
              onClick={() => {
                if (canVote && !hasVoted) {
                  onVote(poll.id, option.id);
                }
              }}
              disabled={!canVote || hasVoted}
              className={`w-full relative overflow-hidden rounded-xl border text-left p-3.5 transition-all ${
                isSelected
                  ? 'bg-[#E8AE33]/15 border-[#E8AE33]'
                  : 'bg-[#1B2539]/80 border-[#33415C] hover:border-slate-500'
              } ${!canVote && !hasVoted ? 'cursor-not-allowed opacity-80' : ''}`}
            >
              {/* Background progress fill if voted */}
              {(hasVoted || isSelected) && (
                <div
                  style={{ width: `${percentage}%` }}
                  className={`absolute inset-y-0 left-0 transition-all duration-700 ${
                    isSelected ? 'bg-[#E8AE33]/25' : 'bg-white/5'
                  }`}
                />
              )}

              <div className="relative z-10 flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  {isSelected && (
                    <CheckCircle2 size={16} className="text-[#E8AE33] shrink-0" />
                  )}
                  <span
                    className={`text-xs sm:text-sm font-medium ${
                      isSelected ? 'text-white font-semibold' : 'text-slate-200'
                    }`}
                  >
                    {option.text}
                  </span>
                </div>

                {(hasVoted || isSelected) && (
                  <span
                    className={`text-xs font-bold font-display ${
                      isSelected ? 'text-[#E8AE33]' : 'text-slate-400'
                    }`}
                  >
                    {percentage}%
                  </span>
                )}
              </div>
            </button>
          );
        })}
      </div>

      {/* Footer Info */}
      <div className="mt-4 pt-3 border-t border-[#27354F] flex items-center justify-between text-xs text-slate-400">
        <span>{totalVotes.toLocaleString()} verified member votes</span>

        {!canVote && (
          <div className="flex items-center gap-1.5 text-slate-400 bg-[#0B1220] px-2.5 py-1 rounded-lg border border-[#27354F]">
            <Lock size={12} />
            <span>
              {currentUser.role === 'partyMember'
                ? `Only ${party?.shortName || 'party'} members`
                : 'Members only'}
            </span>
          </div>
        )}
      </div>
    </div>
  );
};
