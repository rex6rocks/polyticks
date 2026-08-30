import React from 'react';
import { NotificationItem } from '../types';
import { Bell, CheckCheck, ArrowLeft } from 'lucide-react';

interface NotificationsScreenProps {
  notifications: NotificationItem[];
  onMarkAllRead: () => void;
  onPartyClick?: (partyId: string) => void;
  onBack: () => void;
}

export const NotificationsScreen: React.FC<NotificationsScreenProps> = ({
  notifications,
  onMarkAllRead,
  onPartyClick,
  onBack,
}) => {
  return (
    <div className="max-w-2xl mx-auto px-4 py-8 space-y-6">
      <div className="flex items-center justify-between gap-4">
        <button
          onClick={onBack}
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-400 hover:text-white transition-colors"
        >
          <ArrowLeft size={16} />
          <span>Back to Feed</span>
        </button>

        <button
          onClick={onMarkAllRead}
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#FF7A2F] hover:underline"
        >
          <CheckCheck size={14} />
          <span>Mark all as read</span>
        </button>
      </div>

      <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] p-6 shadow-xl space-y-4">
        <div className="flex items-center gap-2 pb-3 border-b border-[#27354F]">
          <Bell size={18} className="text-[#FF7A2F]" />
          <h2 className="font-display font-bold text-base text-white">
            Civic Alerts & Activity
          </h2>
        </div>

        <div className="space-y-3">
          {notifications.length === 0 ? (
            <p className="text-xs text-slate-400 text-center py-8">
              No new alerts. You're completely up to date!
            </p>
          ) : (
            notifications.map((item) => (
              <div
                key={item.id}
                onClick={() => item.partyId && onPartyClick?.(item.partyId)}
                className={`p-4 rounded-2xl border transition-all flex items-start gap-3.5 ${
                  item.read
                    ? 'bg-[#1B2539]/60 border-[#27354F] text-slate-300'
                    : 'bg-[#1B2539] border-[#FF7A2F]/40 text-white shadow-md'
                } ${item.partyId ? 'cursor-pointer hover:border-slate-500' : ''}`}
              >
                <span className="text-2xl shrink-0 mt-0.5">{item.emoji}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-xs sm:text-sm font-medium leading-snug">
                    {item.title}
                  </p>
                  <p className="text-[11px] text-slate-400 mt-1">{item.timeAgo}</p>
                </div>
                {!item.read && (
                  <span className="w-2 h-2 rounded-full bg-[#FF7A2F] shrink-0 mt-2" />
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
