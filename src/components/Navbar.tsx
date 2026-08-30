import React, { useState } from 'react';
import { AppUser, NotificationItem, Party } from '../types';
import { UserAvatar } from './UserAvatar';
import { RoleBadge } from './RoleBadge';
import { PartyTagBadge, RoleTierBadge } from './PartyBadges';
import {
  Vote,
  Compass,
  ShieldCheck,
  Bell,
  User as UserIcon,
  ChevronDown,
  LogOut,
  RefreshCw,
  PlusCircle,
  MapPin,
  CheckCircle2,
  Lock
} from 'lucide-react';

interface NavbarProps {
  currentUser: AppUser;
  allUsers: AppUser[];
  parties: Party[];
  onSwitchUser: (userId: string) => void;
  currentTab: string;
  onNavigate: (tab: string, param?: string) => void;
  onOpenCreatePost: () => void;
  notifications: NotificationItem[];
  onOpenVerification: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  currentUser,
  allUsers,
  parties,
  onSwitchUser,
  currentTab,
  onNavigate,
  onOpenCreatePost,
  notifications,
  onOpenVerification,
}) => {
  const [showUserDropdown, setShowUserDropdown] = useState(false);
  const unreadCount = notifications.filter((n) => !n.read).length;
  const userParty = currentUser.partyId ? parties.find((p) => p.id === currentUser.partyId) : undefined;

  return (
    <header className="sticky top-0 z-40 bg-[#0B1220]/90 backdrop-blur-md border-b border-[#27354F]">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between gap-4">
        {/* Brand Logo & Tag */}
        <div className="flex items-center gap-3">
          <button
            onClick={() => onNavigate('feed')}
            className="flex items-center gap-2 text-left group"
          >
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-[#FF7A2F] via-[#FF8833] to-[#E8AE33] flex items-center justify-center elevate-sm group-hover:scale-105 transition-transform">
              <span className="text-xl">🗳️</span>
            </div>
            <div>
              <div className="flex items-center gap-1.5">
                <span className="text-xl font-bold font-display tracking-tight text-white group-hover:text-[#FF7A2F] transition-colors">
                  Polyticks
                </span>
                <span className="text-[10px] uppercase font-bold tracking-wider px-1.5 py-0.5 rounded bg-[#FF7A2F]/20 text-[#FF7A2F] border border-[#FF7A2F]/40">
                  Civic
                </span>
              </div>
              <p className="text-[11px] text-slate-400 font-medium hidden sm:block">
                Democratic Discourse · Zero-Retention Verification
              </p>
            </div>
          </button>
        </div>

        {/* Primary Desktop Navigation Links (icon-only, #4) */}
        <nav className="hidden md:flex items-center gap-1 bg-[#121B2E]/80 p-1 rounded-xl border border-[#27354F]">
          <button
            onClick={() => onNavigate('feed')}
            aria-label="Feed"
            title="Feed"
            className={`flex items-center justify-center px-3 py-2 rounded-lg transition-all ${
              currentTab === 'feed'
                ? 'bg-[#FF7A2F] text-white elevate-sm'
                : 'text-slate-300 hover:text-white hover:bg-white/5'
            }`}
          >
            <Vote size={16} />
          </button>

          <button
            onClick={() => onNavigate('explore')}
            aria-label="Parties"
            title="Parties"
            className={`flex items-center justify-center px-3 py-2 rounded-lg transition-all ${
              currentTab === 'explore'
                ? 'bg-[#FF7A2F] text-white elevate-sm'
                : 'text-slate-300 hover:text-white hover:bg-white/5'
            }`}
          >
            <Compass size={16} />
          </button>

          <button
            onClick={() => onNavigate('admin')}
            aria-label="Admin ID Queue"
            title="Admin ID Queue"
            className={`flex items-center justify-center px-3 py-2 rounded-lg transition-all ${
              currentTab === 'admin'
                ? 'bg-[#21B579] text-white elevate-sm'
                : 'text-emerald-400 hover:text-emerald-300 hover:bg-emerald-500/10'
            }`}
          >
            <ShieldCheck size={16} />
          </button>
        </nav>

        {/* Right Actions: Create Post, Notification Bell, User Switcher */}
        <div className="flex items-center gap-2 sm:gap-3">
          {/* Create Post Button for Parties and Party Members */}
          <button
            onClick={onOpenCreatePost}
            aria-label="Create Post"
            className="flex items-center justify-center px-3 py-2 rounded-xl bg-gradient-to-r from-[#FF7A2F] to-[#E86A24] text-white shadow-md shadow-orange-500/25 hover:brightness-110 active:scale-95 transition-all"
            title="Create Post"
          >
            <PlusCircle size={15} />
          </button>

          {/* Notifications Bell */}
          <button
            onClick={() => onNavigate('notifications')}
            className={`relative p-2.5 rounded-xl border transition-all ${
              currentTab === 'notifications'
                ? 'bg-[#27354F] text-[#FF7A2F] border-[#FF7A2F]/40'
                : 'bg-[#121B2E] text-slate-300 border-[#27354F] hover:text-white hover:border-slate-600'
            }`}
            title="Notifications"
          >
            <Bell size={17} />
            {unreadCount > 0 && (
              <span className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-[#E63946] text-white text-[10px] font-bold flex items-center justify-center border-2 border-[#0B1220] animate-pulse">
                {unreadCount}
              </span>
            )}
          </button>

          {/* User Profile & Demo Switcher Dropdown */}
          <div className="relative">
            <button
              onClick={() => setShowUserDropdown(!showUserDropdown)}
              className="flex items-center gap-2 p-1.5 sm:px-2.5 sm:py-1.5 rounded-xl bg-[#121B2E] border border-[#27354F] hover:border-slate-600 transition-all text-left"
            >
              <UserAvatar user={currentUser} size="sm" />
              <div className="hidden lg:block">
                <div className="flex items-center gap-1.5">
                  <span className="text-xs font-semibold text-white truncate max-w-[110px]">
                    {currentUser.displayName}
                  </span>
                  {currentUser.isVerified ? (
                    <CheckCircle2 size={12} className="text-[#21B579]" />
                  ) : (
                    <Lock size={12} className="text-slate-400" />
                  )}
                </div>
                <div className="text-[10px] text-slate-400 capitalize">
                  {currentUser.role === 'partyMember' ? 'Member' : currentUser.role}
                </div>
              </div>
              <ChevronDown size={14} className="text-slate-400" />
            </button>

            {/* Dropdown Menu */}
            {showUserDropdown && (
              <div
                className="absolute right-0 mt-2 w-72 bg-[#121B2E] rounded-2xl border border-[#27354F] shadow-2xl p-2 z-50 animate-in fade-in slide-in-from-top-2 duration-150"
                onClick={() => setShowUserDropdown(false)}
              >
                {/* Active User Card */}
                <div className="p-3 bg-[#1B2539] rounded-xl mb-2 border border-[#27354F]">
                  <div className="flex items-center gap-3 mb-2">
                    <UserAvatar user={currentUser} size="md" />
                    <div className="overflow-hidden">
                      <p className="text-xs font-bold text-white truncate">
                        {currentUser.displayName}
                      </p>
                      <p className="text-[11px] text-slate-400 truncate">
                        {currentUser.email}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center justify-between pt-2 border-t border-white/5 flex-wrap gap-1.5">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <RoleBadge role={currentUser.role} small />
                      {userParty && currentUser.role === 'partyMember' && (
                        <>
                          <PartyTagBadge tag={userParty.shortName} emoji={userParty.logoEmoji} small />
                          {currentUser.partyRole && <RoleTierBadge role={currentUser.partyRole} small />}
                        </>
                      )}
                    </div>
                    {currentUser.isVerified ? (
                      <span className="text-[10px] text-[#21B579] font-semibold flex items-center gap-1">
                        <CheckCircle2 size={11} /> Verified ID
                      </span>
                    ) : (
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setShowUserDropdown(false);
                          onOpenVerification();
                        }}
                        className="text-[10px] text-[#FF7A2F] font-bold underline hover:text-[#FF8833]"
                      >
                        Verify Identity →
                      </button>
                    )}
                  </div>
                  {currentUser.communityId && (
                    <div className="mt-2 text-[11px] text-slate-300 flex items-center gap-1 bg-black/20 px-2 py-1 rounded">
                      <MapPin size={11} className="text-[#FF7A2F]" />
                      <span className="truncate">{currentUser.communityId}</span>
                    </div>
                  )}
                </div>

                {/* Quick Account Switcher Header */}
                <div className="px-2 py-1 text-[11px] font-bold uppercase tracking-wider text-slate-400 flex items-center justify-between">
                  <span>Switch Role / Account</span>
                  <RefreshCw size={11} />
                </div>

                {/* Account List */}
                <div className="max-h-52 overflow-y-auto space-y-1 my-1">
                  {allUsers.map((user) => (
                    <button
                      key={user.id}
                      onClick={() => onSwitchUser(user.id)}
                      className={`w-full flex items-center justify-between p-2 rounded-xl text-left transition-all ${
                        user.id === currentUser.id
                          ? 'bg-[#FF7A2F]/15 border border-[#FF7A2F]/40'
                          : 'hover:bg-white/5 text-slate-300'
                      }`}
                    >
                      <div className="flex items-center gap-2 min-w-0">
                        <UserAvatar user={user} size="xs" />
                        <div className="truncate">
                          <p className="text-xs font-semibold text-white truncate">
                            {user.displayName}
                          </p>
                          <p className="text-[10px] text-slate-400 capitalize">
                            {user.role} {user.partyId ? `(${user.partyId.toUpperCase()})` : ''}
                          </p>
                        </div>
                      </div>
                      {user.id === currentUser.id && (
                        <span className="text-[10px] font-bold text-[#FF7A2F] px-1.5 py-0.5 rounded bg-[#FF7A2F]/20">
                          Active
                        </span>
                      )}
                    </button>
                  ))}
                </div>

                {/* Profile & Navigation Links */}
                <div className="border-t border-[#27354F] pt-2 mt-1 space-y-1">
                  <button
                    onClick={() => onNavigate('profile')}
                    className="w-full flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium text-slate-300 hover:text-white hover:bg-white/5"
                  >
                    <UserIcon size={14} />
                    <span>My Profile & Settings</span>
                  </button>
                  <button
                    onClick={() => onNavigate('admin')}
                    className="w-full flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium text-emerald-400 hover:bg-emerald-500/10"
                  >
                    <ShieldCheck size={14} />
                    <span>Moderator ID Console</span>
                  </button>
                  <button
                    onClick={() => onNavigate('login')}
                    className="w-full flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-medium text-red-400 hover:bg-red-500/10"
                  >
                    <LogOut size={14} />
                    <span>Sign Out / Switch Mode</span>
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Mobile Bottom Navigation Bar (icon-only, #4) */}
      <div
        className="md:hidden flex items-center justify-around bg-[#0B1220] border-t border-[#27354F] py-2 px-4"
        style={{ paddingBottom: 'max(0.5rem, env(safe-area-inset-bottom))' }}
      >
        <button
          onClick={() => onNavigate('feed')}
          aria-label="Feed"
          title="Feed"
          className={`flex flex-col items-center p-2 rounded-xl transition-colors ${
            currentTab === 'feed' ? 'text-[#FF7A2F]' : 'text-slate-400'
          }`}
        >
          <Vote size={20} />
        </button>

        <button
          onClick={() => onNavigate('explore')}
          aria-label="Parties"
          title="Parties"
          className={`flex flex-col items-center p-2 rounded-xl transition-colors ${
            currentTab === 'explore' ? 'text-[#FF7A2F]' : 'text-slate-400'
          }`}
        >
          <Compass size={20} />
        </button>

        <button
          onClick={onOpenCreatePost}
          aria-label="Create Post"
          className="flex flex-col items-center justify-center -mt-5 w-11 h-11 rounded-full bg-[#FF7A2F] text-white shadow-lg shadow-orange-500/30"
        >
          <PlusCircle size={22} />
        </button>

        <button
          onClick={() => onNavigate('admin')}
          aria-label="Admin"
          title="Admin"
          className={`flex flex-col items-center p-2 rounded-xl transition-colors ${
            currentTab === 'admin' ? 'text-[#21B579]' : 'text-slate-400'
          }`}
        >
          <ShieldCheck size={20} />
        </button>

        <button
          onClick={() => onNavigate('profile')}
          aria-label="Profile"
          title="Profile"
          className={`flex flex-col items-center p-2 rounded-xl transition-colors ${
            currentTab === 'profile' ? 'text-[#FF7A2F]' : 'text-slate-400'
          }`}
        >
          <UserIcon size={20} />
        </button>
      </div>
    </header>
  );
};
