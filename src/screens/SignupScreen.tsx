import React, { useState } from 'react';
import { UserRole, Party, AppUser } from '../types';
import { Users, Landmark, Award, ArrowLeft, ArrowRight } from 'lucide-react';

interface SignupScreenProps {
  parties: Party[];
  onRegister: (newUser: AppUser) => void;
  onBackToLogin: () => void;
}

// Party-member direct signup is disabled (#8): members are created by promoting
// Janta accounts via the join-request flow. The flow below is retained (not deleted)
// and reserved for reuse as the party member application path.
const ALLOW_MEMBER_SIGNUP = false;

export const SignupScreen: React.FC<SignupScreenProps> = ({
  parties,
  onRegister,
  onBackToLogin,
}) => {
  const [role, setRole] = useState<UserRole>('janta');
  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('+91 98765 00000');
  const [selectedPartyId, setSelectedPartyId] = useState(parties[0]?.id || 'p1');
  const [communityId, setCommunityId] = useState('Indiranagar Ward #84');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!displayName.trim()) return;

    const colors = ['#3FBFB4', '#E8697A', '#E8AE33', '#A29BFE', '#FD79A8', '#6C5CE7'];
    const randomColor = colors[Math.floor(Math.random() * colors.length)];

    const newUser: AppUser = {
      id: `u_${Date.now()}`,
      displayName: displayName.trim(),
      role,
      partyId: role === 'partyMember' || role === 'party' ? selectedPartyId : undefined,
      avatarColor: randomColor,
      email: email.trim() || `${displayName.toLowerCase().replace(/\s+/g, '')}@polyticks.in`,
      phone: phone.trim(),
      isAnonymous: false,
      isVerified: false,
      communityId: communityId.trim() || 'Indiranagar Ward #84',
      createdAt: new Date().toISOString(),
    };

    onRegister(newUser);
  };

  return (
    <div className="min-h-[85vh] flex items-center justify-center px-4 py-8">
      <div className="w-full max-w-lg space-y-6">
        <button
          onClick={onBackToLogin}
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-400 hover:text-white transition-colors"
        >
          <ArrowLeft size={16} />
          <span>Back to Sign In</span>
        </button>

        <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] p-6 sm:p-8 shadow-2xl space-y-6">
          <div>
            <h2 className="text-2xl font-bold font-display text-white">
              Join Polyticks
            </h2>
            <p className="text-xs text-slate-400 mt-1">
              Select your democratic civic role to begin.
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Role Selection */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-2">
                I am registering as:
              </label>
              <div className={`grid gap-2 ${ALLOW_MEMBER_SIGNUP ? 'grid-cols-3' : 'grid-cols-2'}`}>
                <button
                  type="button"
                  onClick={() => setRole('janta')}
                  className={`p-3 rounded-2xl border text-center transition-all ${
                    role === 'janta'
                      ? 'bg-[#3FBFB4]/20 border-[#3FBFB4] text-white shadow-sm'
                      : 'bg-[#1B2539] border-[#27354F] text-slate-400 hover:text-slate-200'
                  }`}
                >
                  <Users size={20} className="mx-auto mb-1 text-[#3FBFB4]" />
                  <p className="text-xs font-bold">Janta</p>
                  <p className="text-[10px] text-slate-400">Citizen</p>
                </button>

                {ALLOW_MEMBER_SIGNUP && (
                  <button
                    type="button"
                    onClick={() => setRole('partyMember')}
                    className={`p-3 rounded-2xl border text-center transition-all ${
                      role === 'partyMember'
                        ? 'bg-[#E8AE33]/20 border-[#E8AE33] text-white shadow-sm'
                        : 'bg-[#1B2539] border-[#27354F] text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <Award size={20} className="mx-auto mb-1 text-[#E8AE33]" />
                    <p className="text-xs font-bold">Member</p>
                    <p className="text-[10px] text-slate-400">Party Member</p>
                  </button>
                )}

                <button
                  type="button"
                  onClick={() => setRole('party')}
                  className={`p-3 rounded-2xl border text-center transition-all ${
                    role === 'party'
                      ? 'bg-[#E8697A]/20 border-[#E8697A] text-white shadow-sm'
                      : 'bg-[#1B2539] border-[#27354F] text-slate-400 hover:text-slate-200'
                  }`}
                >
                  <Landmark size={20} className="mx-auto mb-1 text-[#E8697A]" />
                  <p className="text-xs font-bold">Party</p>
                  <p className="text-[10px] text-slate-400">Official Entity</p>
                </button>
              </div>
            </div>

            {/* Party Affiliation selector if Member or Party */}
            {(role === 'partyMember' || role === 'party') && (
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                  Affiliated Political Party:
                </label>
                <select
                  value={selectedPartyId}
                  onChange={(e) => setSelectedPartyId(e.target.value)}
                  className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-[#FF7A2F]"
                >
                  {parties.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.logoEmoji} {p.name} ({p.shortName})
                    </option>
                  ))}
                </select>
              </div>
            )}

            {/* Name */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Full Name / Entity Name:
              </label>
              <input
                type="text"
                required
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="e.g. Ramesh Varma"
                className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-[#FF7A2F]"
              />
            </div>

            {/* Email */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Email Address:
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="e.g. ramesh@gmail.com"
                className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-[#FF7A2F]"
              />
            </div>

            {/* Phone */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Mobile Number:
              </label>
              <input
                type="text"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+91 98765 00000"
                className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-[#FF7A2F]"
              />
            </div>

            {/* Local Ward / Community */}
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                Ward / Neighborhood Community:
              </label>
              <input
                type="text"
                value={communityId}
                onChange={(e) => setCommunityId(e.target.value)}
                placeholder="e.g. Indiranagar Ward #84"
                className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-[#FF7A2F]"
              />
            </div>

            <button
              type="submit"
              disabled={!displayName.trim()}
              className="w-full py-3 rounded-2xl bg-gradient-to-r from-[#FF7A2F] to-[#E86A24] text-white text-xs font-bold elevate-sm hover:brightness-110 disabled:opacity-50 transition-all flex items-center justify-center gap-2"
            >
              <span>Complete Registration</span>
              <ArrowRight size={16} />
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};
