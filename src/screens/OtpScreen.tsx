import React, { useState } from 'react';
import { ArrowLeft, CheckCircle2, ShieldCheck, Sparkles } from 'lucide-react';

interface OtpScreenProps {
  phoneNumber: string;
  onVerify: (otp: string) => void;
  onBack: () => void;
}

export const OtpScreen: React.FC<OtpScreenProps> = ({
  phoneNumber,
  onVerify,
  onBack,
}) => {
  const [otp, setOtp] = useState('123456');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (otp.length >= 4) {
      onVerify(otp);
    }
  };

  return (
    <div className="min-h-[85vh] flex items-center justify-center px-4 py-8">
      <div className="w-full max-w-md space-y-6">
        <button
          onClick={onBack}
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-400 hover:text-white transition-colors"
        >
          <ArrowLeft size={16} />
          <span>Change Number</span>
        </button>

        <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] p-6 sm:p-8 shadow-2xl space-y-5">
          <div className="text-center space-y-1">
            <div className="w-12 h-12 rounded-2xl bg-[#21B579]/20 text-[#21B579] flex items-center justify-center text-xl mx-auto mb-2">
              <ShieldCheck size={24} />
            </div>
            <h2 className="text-xl font-bold font-display text-white">
              Enter Verification Code
            </h2>
            <p className="text-xs text-slate-300">
              6-digit OTP sent to <span className="text-white font-mono">{phoneNumber}</span>
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <input
                type="text"
                maxLength={6}
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                placeholder="123456"
                className="w-full bg-[#0B1220] border border-[#27354F] rounded-2xl py-3.5 text-center text-2xl font-mono tracking-widest text-white focus:outline-none focus:border-[#FF7A2F]"
              />
            </div>

            {/* Auto Fill Demo OTP Button */}
            <div className="text-center">
              <button
                type="button"
                onClick={() => setOtp('123456')}
                className="text-xs text-[#FF7A2F] font-semibold hover:underline inline-flex items-center gap-1"
              >
                <Sparkles size={12} />
                <span>Auto-fill Demo Code (123456)</span>
              </button>
            </div>

            <button
              type="submit"
              disabled={otp.length < 4}
              className="w-full py-3 rounded-2xl bg-gradient-to-r from-[#FF7A2F] to-[#E86A24] text-white text-xs font-bold elevate-sm hover:brightness-110 disabled:opacity-50 transition-all flex items-center justify-center gap-2"
            >
              <CheckCircle2 size={16} />
              <span>Verify & Sign In</span>
            </button>
          </form>

          <div className="pt-3 border-t border-[#27354F] text-center text-xs text-slate-400">
            Didn't receive code?{' '}
            <button
              onClick={() => alert('Simulated new OTP dispatched!')}
              className="text-slate-200 font-bold hover:underline"
            >
              Resend OTP
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
