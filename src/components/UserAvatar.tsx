import React from 'react';
import { AppUser } from '../types';

interface UserAvatarProps {
  user: Partial<AppUser> | null;
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  className?: string;
}

export const UserAvatar: React.FC<UserAvatarProps> = ({ user, size = 'md', className = '' }) => {
  const sizeMap = {
    xs: 'w-6 h-6 text-xs',
    sm: 'w-8 h-8 text-xs',
    md: 'w-10 h-10 text-sm',
    lg: 'w-12 h-12 text-base',
    xl: 'w-16 h-16 text-xl',
  };

  const initial = user?.displayName ? user.displayName.charAt(0).toUpperCase() : '?';
  const bgColor = user?.avatarColor || '#3FBFB4';

  if (user?.avatarUrl) {
    return (
      <img
        src={user.avatarUrl}
        alt={user.displayName || 'User'}
        className={`rounded-full object-cover border border-white/10 ${sizeMap[size]} ${className}`}
      />
    );
  }

  return (
    <div
      style={{ backgroundColor: bgColor }}
      className={`rounded-full flex items-center justify-center font-bold text-white shadow-sm shrink-0 select-none ${sizeMap[size]} ${className}`}
    >
      {initial}
    </div>
  );
};
