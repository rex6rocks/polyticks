import React from 'react';
import { AppUser, Party } from '../types';
import { UserAvatar } from '../components/UserAvatar';
import { RoleBadge } from '../components/RoleBadge';
import { PartyTagBadge, RoleTierBadge } from '../components/PartyBadges';
import {
  MapPin,
  EyeOff,
  Eye,
  LogOut,
  RefreshCw,
  CheckCircle2,
  UserMinus,
  RotateCcw,
  Unlink,
  ShieldCheck
} from 'lucide-react';

interface ProfileScreenProps {
  currentUser: AppUser;
  parties: Party[];
  allUsers: AppUser[];
  onUpdateUser: (user: AppUser) => void;
  onSwitchUser: (userId: string) => void;
  onOpenVerification: () => void;
  onReKyc?: () => void;
  onUnlinkAccount?: () => void;
  onPartyClick: (partyId: string) => void;
  onLogout: () => void;
  onLeaveParty?: () => void;
}

export const ProfileScreen: React.FC<ProfileScreenProps> = ({
  currentUser,
  parties,
  allUsers,
  onUpdateUser,
  onSwitchUser,
  onOpenVerification,
  onReKyc,
  onUnlinkAccount,
  onPartyClick,
  onLogout,
  onLeaveParty,
}) => {
  const toggleAnonymous = () => {
    // Anonymous mode is a Janta-only capability (#1)
    if (currentUser.role !== 'janta') return;
    onUpdateUser({
      ...currentUser,
      isAnonymous: !currentUser.isAnonymous,
    });
  };

  const userParty = currentUser.partyId
    ? parties.find((p) => p.id === currentUser.partyId)
    : undefined;

  return (
    <div className="max-w-3xl mx-auto px-4 py-8 space-y-6">
      {/* Profile Card */}
      <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] p-6 sm:p-8 shadow-xl space-y-6">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-5 text-center sm:text-left">
          <UserAvatar user={currentUser} size="xl" />

          <div className="space-y-1.5 flex-1 min-w-0">
            <div className="flex items-center justify-center sm:justify-start gap-2 flex-wrap">
              <h2 className="text-xl font-bold font-display text-white">
                {currentUser.displayName}
              </h2>
              <RoleBadge role={currentUser.role} />
            </div>

            <p className="text-xs text-slate-400 font-mono">{currentUser.email}</p>

            <div className="flex items-center justify-center sm:justify-start gap-3 text-xs text-slate-300 pt-1 flex-wrap">
              {currentUser.communityId && (
                <span className="flex items-center gap-1">
                  <MapPin size={13} className="text-[#FF7A2F]" />
                  <span>{currentUser.communityId}</span>
                </span>
              )}
              <span className="flex items-center gap-1">
                {currentUser.isVerified ? (
                  <span className="text-[#21B579] font-semibold flex items-center gap-1">
                    <CheckCircle2 size={13} /> Verified Civic Identity
                  </span>
                ) : (
                  <button
                    onClick={onOpenVerification}
                    className="text-[#FF7A2F] font-bold underline hover:text-[#FF8833]"
                  >
                    Verify Identity →
                  </button>
                )}
              </span>
            </div>
          </div>
        </div>

        {/* Identity & Security Actions: Re-KYC and Unlink Account */}
        <div className="p-4 rounded-2xl bg-[#1B2539] border border-[#27354F] space-y-3">
          <h4 className="text-xs font-bold text-white uppercase tracking-wider flex items-center gap-1.5">
            <ShieldCheck size={14} className="text-[#21B579]" />
            <span>Account Verification & Identity Controls</span>
          </h4>

          <div className="flex flex-wrap items-center gap-2.5 pt-1">
            {/* Re-KYC Button */}
            <button
              onClick={() => {
                if (onReKyc) {
                  onReKyc();
                } else {
                  onOpenVerification();
                }
              }}
              className="px-3.5 py-2 rounded-xl bg-[#0B1220] hover:bg-[#121B2E] text-slate-200 border border-[#27354F] text-xs font-bold transition-all flex items-center gap-1.5 hover:text-white"
            >
              <RotateCcw size={14} className="text-[#FF7A2F]" />
              <span>{currentUser.isVerified ? 'Re-KYC (Re-verify ID)' : 'Start Identity Verification'}</span>
            </button>

            {/* Unlink Account Button */}
            {onUnlinkAccount && (
              <button
                onClick={() => {
                  if (window.confirm('Are you sure you want to unlink your account? This will reset your verified civic badge and party affiliation.')) {
                    onUnlinkAccount();
                  }
                }}
                className="px-3.5 py-2 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400 border border-red-500/30 text-xs font-bold transition-all flex items-center gap-1.5"
              >
                <Unlink size={14} />
                <span>Unlink Account Credentials</span>
              </button>
            )}
          </div>
        </div>

        {/* Member Affiliation Callout if partyMember */}
        {userParty && (
          <div className="p-4 rounded-2xl bg-[#1B2539] border border-[#27354F] space-y-3">
            <div className="flex items-center justify-between gap-3 flex-wrap">
              <div className="flex items-center gap-3">
                <span className="text-3xl">{userParty.logoEmoji}</span>
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="text-xs font-bold text-white">
                      Affiliated Party: {userParty.name}
                    </p>
                    <PartyTagBadge tag={userParty.shortName} emoji={userParty.logoEmoji} small />
                    {currentUser.partyRole && <RoleTierBadge role={currentUser.partyRole} small />}
                  </div>
                  <p className="text-[11px] text-slate-400 mt-0.5">
                    You can participate and vote in official {userParty.shortName} member policy ballots.
                  </p>
                </div>
              </div>
              <button
                onClick={() => onPartyClick(userParty.id)}
                className="px-3.5 py-1.5 rounded-xl bg-[#0B1220] hover:bg-[#121B2E] text-xs font-bold text-white transition-colors"
              >
                View Party
              </button>
            </div>
            {onLeaveParty && (
              <div className="pt-2 border-t border-[#27354F]/60">
                <button
                  onClick={onLeaveParty}
                  className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-red-400 hover:text-red-300 transition-colors"
                >
                  <UserMinus size={13} />
                  <span>Leave Party (account reverts to Janta)</span>
                </button>
              </div>
            )}
          </div>
        )}

        {/* Janta Citizen Privacy Toggle */}
        {currentUser.role === 'janta' && (
          <div className="p-5 rounded-2xl bg-[#1B2539] border border-[#27354F] flex items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                {currentUser.isAnonymous ? (
                  <EyeOff size={18} className="text-[#3FBFB4]" />
                ) : (
                  <Eye size={18} className="text-slate-400" />
                )}
                <h4 className="text-xs sm:text-sm font-bold text-white font-display">
                  Citizen Anonymous Mode
                </h4>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                When active, your name is displayed as <span className="text-slate-200">"Anonymous Citizen"</span> on public posts and comment threads.
              </p>
            </div>

            <button
              onClick={toggleAnonymous}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all ${
                currentUser.isAnonymous
                  ? 'bg-[#3FBFB4] text-[#0B1220] elevate-sm'
                  : 'bg-[#0B1220] text-slate-300 border border-[#33415C] hover:text-white'
              }`}
            >
              {currentUser.isAnonymous ? 'Active (Hidden)' : 'Disabled (Public)'}
            </button>
          </div>
        )}
      </div>

      {/* Quick Demo Switcher Section */}
      <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] p-6 space-y-4 shadow-xl">
        <div className="flex items-center justify-between">
          <h3 className="font-display font-bold text-sm text-white flex items-center gap-2">
            <RefreshCw size={15} className="text-[#FF7A2F]" />
            <span>Switch Role / Demo Persona</span>
          </h3>
          <span className="text-[11px] text-slate-400">
            Instant Test Accounts
          </span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 max-h-80 overflow-y-auto pr-1">
          {allUsers.map((user) => (
            <button
              key={user.id}
              onClick={() => onSwitchUser(user.id)}
              className={`p-3 rounded-2xl border text-left flex items-center justify-between gap-3 transition-all ${
                user.id === currentUser.id
                  ? 'bg-[#FF7A2F]/15 border-[#FF7A2F] text-white shadow-sm'
                  : 'bg-[#1B2539] border-[#27354F] text-slate-300 hover:border-slate-500'
              }`}
            >
              <div className="flex items-center gap-2.5 min-w-0">
                <UserAvatar user={user} size="sm" />
                <div className="truncate">
                  <p className="text-xs font-bold text-white truncate">
                    {user.displayName}
                  </p>
                  <p className="text-[10px] text-slate-400 capitalize">
                    {user.role} {user.partyId ? `(${user.partyId.toUpperCase()})` : ''}
                  </p>
                </div>
              </div>
              {user.id === currentUser.id && (
                <span className="text-[10px] font-bold text-[#FF7A2F] px-2 py-0.5 rounded-full bg-[#FF7A2F]/20">
                  Current
                </span>
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Sign Out Button */}
      <div className="text-center pt-2">
        <button
          onClick={onLogout}
          className="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-red-500/10 hover:bg-red-500/20 text-red-400 text-xs font-bold border border-red-500/30 transition-colors"
        >
          <LogOut size={14} />
          <span>Sign Out / Switch Mode</span>
        </button>
      </div>
    </div>
  );
};
