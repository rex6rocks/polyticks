import React from 'react';
import { UserRole } from '../types';
import { Users, Landmark, Award } from 'lucide-react';

interface RoleBadgeProps {
  role: UserRole;
  small?: boolean;
  className?: string;
}

export const RoleBadge: React.FC<RoleBadgeProps> = ({ role, small = false, className = '' }) => {
  if (role === 'party') {
    return (
      <span
        className={`inline-flex items-center gap-1 font-semibold rounded-full border transition-all ${
          small ? 'px-2 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs'
        } bg-[#E8697A]/15 text-[#E8697A] border-[#E8697A]/30 ${className}`}
      >
        <Landmark size={small ? 10 : 12} />
        <span>Party</span>
      </span>
    );
  }

  if (role === 'partyMember') {
    return (
      <span
        className={`inline-flex items-center gap-1 font-semibold rounded-full border transition-all ${
          small ? 'px-2 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs'
        } bg-[#E8AE33]/15 text-[#E8AE33] border-[#E8AE33]/30 ${className}`}
      >
        <Award size={small ? 10 : 12} />
        <span>Party Member</span>
      </span>
    );
  }

  return (
    <span
      className={`inline-flex items-center gap-1 font-semibold rounded-full border transition-all ${
        small ? 'px-2 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs'
      } bg-[#3FBFB4]/15 text-[#3FBFB4] border-[#3FBFB4]/30 ${className}`}
    >
      <Users size={small ? 10 : 12} />
      <span>Janta (Citizen)</span>
    </span>
  );
};
