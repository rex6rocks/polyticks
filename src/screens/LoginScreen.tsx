import React, { useState } from 'react';
import { AppUser, Party } from '../types';
import { UserAvatar } from '../components/UserAvatar';
import { RoleBadge } from '../components/RoleBadge';
import { PartyTagBadge, RoleTierBadge } from '../components/PartyBadges';
import { Phone, ArrowRight, ShieldCheck } from 'lucide-react';

interface LoginScreenProps {
  allUsers: AppUser[];
  parties: Party[];
  onSelectUser: (userId: string) => void;
  onRequestOtp: (phone: string) => void;
  onNavigateToSignup: () => void;
  onNavigateToAdmin: () => void;
  onLoginLater?: () => void;
}

export const LoginScreen: React.FC<LoginScreenProps> = ({
  allUsers,
  parties,
  onSelectUser,
  onRequestOtp,
  onNavigateToSignup,
  onNavigateToAdmin,
  onLoginLater,
}) => {
  const [phoneNumber, setPhoneNumber] = useState('+91 98765 43210');

  const handlePhoneSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!phoneNumber.trim()) return;
    onRequestOtp(phoneNumber.trim());
  };

  return (
    <div className="min-h-[85vh] flex items-center justify-center px-4 py-8">
      <div className="w-full max-w-lg space-y-6">
        {/* Brand Banner */}
        <div className="text-center space-y-2">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-[#FF7A2F] to-[#E8AE33] flex items-center justify-center text-3xl elevate-md mx-auto">
            🗳️
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold font-display text-white tracking-tight">
            Welcome to Polyticks
          </h1>
          <p className="text-xs sm:text-sm text-slate-300 max-w-sm mx-auto">
            Democratic, uncensored political social media with zero-retention identity verification.
          </p>
        </div>

        {/* Main Phone Login Card */}
        <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] p-6 sm:p-8 shadow-2xl space-y-5">
          <form onSubmit={handlePhoneSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Phone Number (OTP Verification):
              </label>
              <div className="relative">
                <Phone size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  value={phoneNumber}
                  onChange={(e) => setPhoneNumber(e.target.value)}
                  placeholder="+91 98765 43210"
                  className="w-full bg-[#0B1220] border border-[#27354F] rounded-2xl pl-10 pr-4 py-3 text-sm text-white focus:outline-none focus:border-[#FF7A2F]"
                />
              </div>
            </div>

            <button
              type="submit"
              className="w-full py-3 rounded-2xl bg-gradient-to-r from-[#FF7A2F] to-[#E86A24] text-white text-xs font-bold elevate-sm hover:brightness-110 active:scale-98 transition-all flex items-center justify-center gap-2"
            >
              <span>Send One-Time Password (OTP)</span>
              <ArrowRight size={16} />
            </button>
          </form>

          {/* Divider */}
          <div className="relative flex items-center justify-center my-4">
            <div className="border-t border-[#27354F] w-full" />
            <span className="bg-[#121B2E] px-3 text-[11px] font-bold uppercase tracking-wider text-slate-400">
              Or One-Click Demo Personas
            </span>
          </div>

          {/* Quick Demo Accounts Grid */}
          <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
            {allUsers.map((user) => (
              <button
                key={user.id}
                onClick={() => onSelectUser(user.id)}
                className="w-full p-3 rounded-2xl bg-[#1B2539] hover:bg-[#27354F] border border-[#27354F] text-left flex items-center justify-between gap-3 transition-all hover:scale-[1.01]"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <UserAvatar user={user} size="sm" />
                  <div className="truncate">
                    <p className="text-xs font-bold text-white truncate">
                      {user.displayName}
                    </p>
                    <p className="text-[10px] text-slate-400">
                      {user.email} {user.communityId ? `· ${user.communityId}` : ''}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-1.5 shrink-0">
                  <RoleBadge role={user.role} small />
                  {user.role === 'partyMember' && user.partyId &&
                    parties
                      .filter((p) => p.id === user.partyId)
                      .map((p) => <PartyTagBadge key={p.id} tag={p.shortName} emoji={p.logoEmoji} small />)
                  }
                  {user.partyRole && <RoleTierBadge role={user.partyRole} small />}
                  <ArrowRight size={14} className="text-slate-400" />
                </div>
              </button>
            ))}
          </div>

          {/* Login Later / Guest Browse Action */}
          {onLoginLater && (
            <button
              type="button"
              onClick={onLoginLater}
              className="w-full py-2.5 rounded-2xl bg-[#0B1220] hover:bg-[#1B2539] border border-[#27354F] text-slate-300 hover:text-white text-xs font-bold transition-all flex items-center justify-center gap-2"
            >
              <span>Login Later (Browse as Guest Citizen)</span>
            </button>
          )}

          {/* Bottom Switch Links */}
          <div className="pt-2 border-t border-[#27354F] flex items-center justify-between text-xs">
            <button
              onClick={onNavigateToSignup}
              className="text-[#FF7A2F] font-bold hover:underline"
            >
              Register New Account →
            </button>

            <button
              onClick={onNavigateToAdmin}
              className="text-emerald-400 font-semibold hover:underline flex items-center gap-1"
            >
              <ShieldCheck size={13} />
              <span>Admin Queue</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
