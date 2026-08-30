import React, { useState } from 'react';
import { Party, AppUser } from '../types';
import { Compass, Search, UserCheck, UserPlus } from 'lucide-react';

interface ExploreScreenProps {
  parties: Party[];
  currentUser: AppUser;
  isFollowingParty: (partyId: string) => boolean;
  onToggleFollow: (partyId: string) => void;
  onPartyClick: (partyId: string) => void;
}

export const ExploreScreen: React.FC<ExploreScreenProps> = ({
  parties,
  currentUser,
  isFollowingParty,
  onToggleFollow,
  onPartyClick,
}) => {
  const [searchQuery, setSearchQuery] = useState('');

  const filteredParties = parties.filter(
    (p) =>
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.shortName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.description.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="max-w-5xl mx-auto px-4 py-6 space-y-6">
      {/* Header Banner */}
      <div className="bg-gradient-to-r from-[#121B2E] to-[#1B2539] rounded-3xl border border-[#27354F] p-6 sm:p-8 shadow-xl relative overflow-hidden">
        <div className="relative z-10 max-w-2xl space-y-2">
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#FF7A2F]/20 text-[#FF7A2F] border border-[#FF7A2F]/40 text-xs font-bold">
            <Compass size={13} />
            <span>Civic Directory</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold font-display text-white">
            Explore Political Parties & Initiatives
          </h1>
          <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
            Follow recognized parties to receive direct manifestos, participate in grassroots consultations, and hold political leaders accountable.
          </p>
        </div>

        {/* Search bar inside header */}
        <div className="mt-6 max-w-md relative">
          <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search party by name, symbol, or ideology..."
            className="w-full bg-[#0B1220]/90 border border-[#27354F] rounded-2xl pl-10 pr-4 py-2.5 text-xs sm:text-sm text-white placeholder-slate-500 focus:outline-none focus:border-[#FF7A2F]"
          />
        </div>
      </div>

      {/* Party Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        {filteredParties.map((party) => {
          const following = isFollowingParty(party.id);
          const isUserParty = currentUser.partyId === party.id;

          return (
            <div
              key={party.id}
              className="bg-[#121B2E] rounded-3xl border border-[#27354F] overflow-hidden shadow-lg flex flex-col justify-between hover:border-slate-500/60 transition-all group"
            >
              {/* Card Top Color Accent */}
              <div
                style={{ backgroundColor: party.bannerColor }}
                className="h-20 w-full relative p-3 flex justify-end"
              >
                {isUserParty && (
                  <span className="relative z-10 px-2.5 py-1 rounded-full bg-black/40 backdrop-blur-md text-[#E8AE33] border border-[#E8AE33]/40 text-[10px] font-bold h-fit">
                    ★ Your Affiliated Party
                  </span>
                )}
                <div className="w-14 h-14 rounded-2xl bg-[#1B2539] border-2 border-[#121B2E] flex items-center justify-center text-3xl shadow-xl absolute -bottom-7 left-5 group-hover:scale-105 transition-transform">
                  {party.logoEmoji}
                </div>
              </div>

              {/* Card Body */}
              <div className="pt-9 p-5 flex-1 flex flex-col justify-between space-y-4">
                <div>
                  <div className="flex items-center gap-2 flex-wrap mb-1">
                    <h3
                      onClick={() => onPartyClick(party.id)}
                      className="font-display font-bold text-base text-white hover:text-[#FF7A2F] cursor-pointer transition-colors"
                    >
                      {party.name}
                    </h3>
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#E8697A]/15 text-[#E8697A] border border-[#E8697A]/30">
                      {party.shortName}
                    </span>
                  </div>

                  <p className="text-xs text-slate-300 line-clamp-3 leading-relaxed mt-2">
                    {party.description}
                  </p>
                </div>

                {/* Party Metrics */}
                <div className="grid grid-cols-2 gap-2 pt-3 border-t border-[#27354F] text-center">
                  <div className="bg-[#1B2539] p-2 rounded-xl">
                    <p className="text-xs font-bold text-white">
                      {party.followerCount.toLocaleString()}
                    </p>
                    <p className="text-[10px] text-slate-400">Followers</p>
                  </div>
                  <div className="bg-[#1B2539] p-2 rounded-xl">
                    <p className="text-xs font-bold text-[#E8AE33]">
                      {party.memberCount.toLocaleString()}
                    </p>
                    <p className="text-[10px] text-slate-400">Members</p>
                  </div>
                </div>

                {/* Follow Button & Explore action */}
                <div className="flex gap-2 pt-2">
                  <button
                    onClick={() => onToggleFollow(party.id)}
                    className={`flex-1 py-2 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all ${
                      following
                        ? 'bg-[#1B2539] text-slate-300 border border-[#33415C] hover:text-red-400'
                        : 'bg-[#FF7A2F] text-white hover:bg-[#E86A24] shadow-md shadow-orange-500/20'
                    }`}
                  >
                    {following ? (
                      <>
                        <UserCheck size={14} className="text-[#21B579]" />
                        <span>Following</span>
                      </>
                    ) : (
                      <>
                        <UserPlus size={14} />
                        <span>Follow</span>
                      </>
                    )}
                  </button>

                  <button
                    onClick={() => onPartyClick(party.id)}
                    className="px-3.5 py-2 rounded-xl bg-[#1B2539] hover:bg-[#27354F] text-white text-xs font-bold transition-colors"
                  >
                    View
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
