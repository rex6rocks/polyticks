import React from 'react';
import { PartyRole, PARTY_ROLE_LABELS, TOP_TIER_PARTY_ROLES } from '../types';

interface PartyTagBadgeProps {
  tag: string; // party shortName
  emoji?: string;
  small?: boolean;
  className?: string;
}

/** Tag showing the single associated party of a party member (#5). */
export const PartyTagBadge: React.FC<PartyTagBadgeProps> = ({ tag, emoji, small = false, className = '' }) => (
  <span
    title={`Member of ${tag}`}
    className={`inline-flex items-center gap-1 font-semibold rounded-full border transition-all ${
      small ? 'px-2 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs'
    } bg-[#E8AE33]/15 text-[#E8AE33] border-[#E8AE33]/30 ${className}`}
  >
    {emoji && <span>{emoji}</span>}
    <span>{tag}</span>
  </span>
);

interface RoleTierBadgeProps {
  role: PartyRole;
  small?: boolean;
  className?: string;
}

/** Hierarchy tier badge for a party member's assigned role (#6.b).
 *  Top-tier roles render violet, lower tiers render sky blue. */
export const RoleTierBadge: React.FC<RoleTierBadgeProps> = ({ role, small = false, className = '' }) => {
  const isTopTier = TOP_TIER_PARTY_ROLES.includes(role);
  return (
    <span
      title={`Party role: ${PARTY_ROLE_LABELS[role]}`}
      className={`inline-flex items-center gap-1 font-semibold rounded-full border transition-all ${
        small ? 'px-2 py-0.5 text-[10px]' : 'px-2.5 py-1 text-xs'
      } ${
        isTopTier
          ? 'bg-[#A78BFA]/15 text-[#A78BFA] border-[#A78BFA]/30'
          : 'bg-[#7DD3FC]/15 text-[#7DD3FC] border-[#7DD3FC]/30'
      } ${className}`}
    >
      <span>{PARTY_ROLE_LABELS[role]}</span>
    </span>
  );
};
