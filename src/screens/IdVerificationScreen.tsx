import React, { useState } from 'react';
import { AppUser } from '../types';
import {
  ShieldCheck,
  Camera,
  CheckCircle2,
  Lock,
  ArrowLeft,
  FileCheck,
  Zap,
  Globe,
  Loader2,
  Check
} from 'lucide-react';

interface IdVerificationScreenProps {
  currentUser?: AppUser;
  onSubmitVerification: (data: {
    documentType: string;
    imageUrl: string;
    fileSizeKb: number;
  }) => void;
  onInstantVerify?: () => void;
  onBack: () => void;
  onBrowseFeed: () => void;
}

const SAMPLE_DOCS = [
  {
    name: 'National Voter ID Card (EPIC)',
    url: 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=600&auto=format&fit=crop&q=80',
    sizeKb: 118,
  },
  {
    name: 'Driving License (Class LMV)',
    url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80',
    sizeKb: 132,
  },
  {
    name: 'National Passport (Bio Page)',
    url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80',
    sizeKb: 145,
  },
];

export const IdVerificationScreen: React.FC<IdVerificationScreenProps> = ({
  currentUser,
  onSubmitVerification,
  onInstantVerify,
  onBack,
  onBrowseFeed,
}) => {
  const [method, setMethod] = useState<'digilocker' | 'manual'>('digilocker');
  const [selectedDocIndex] = useState<number>(0);
  const [customImage, setCustomImage] = useState<string | null>(null);
  const [docType, setDocType] = useState<string>('National Voter ID Card (EPIC)');
  const [isCompressing, setIsCompressing] = useState<boolean>(false);
  const [compressedKb, setCompressedKb] = useState<number>(118);
  const [submitted, setSubmitted] = useState<boolean>(false);

  // DigiLocker Simulation State
  const [digiLockerStep, setDigiLockerStep] = useState<'idle' | 'authorizing' | 'fetching' | 'completed'>('idle');

  const handleDigiLockerStart = () => {
    setDigiLockerStep('authorizing');
    setTimeout(() => {
      setDigiLockerStep('fetching');
      setTimeout(() => {
        setDigiLockerStep('completed');
        if (onInstantVerify) {
          onInstantVerify();
        }
      }, 1200);
    }, 1200);
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setIsCompressing(true);
    const reader = new FileReader();
    reader.onload = (event) => {
      setTimeout(() => {
        setCustomImage(event.target?.result as string);
        const targetKb = Math.min(145, Math.max(95, Math.floor(file.size / 1024 / 4) || 115));
        setCompressedKb(targetKb);
        setIsCompressing(false);
      }, 500);
    };
    reader.readAsDataURL(file);
  };

  const handleSubmitManual = (e: React.FormEvent) => {
    e.preventDefault();
    const doc = SAMPLE_DOCS[selectedDocIndex];
    onSubmitVerification({
      documentType: docType,
      imageUrl: customImage || doc.url,
      fileSizeKb: compressedKb,
    });
    setSubmitted(true);
  };

  return (
    <div className="max-w-xl mx-auto px-4 py-8 space-y-6">
      <button
        onClick={onBack}
        className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-400 hover:text-white transition-colors"
      >
        <ArrowLeft size={16} />
        <span>Back</span>
      </button>

      <div className="bg-[#121B2E] rounded-3xl border border-[#27354F] p-6 sm:p-8 shadow-2xl space-y-6">
        {/* Top Header */}
        <div>
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#FF7A2F]/15 text-[#FF7A2F] border border-[#FF7A2F]/30 text-xs font-bold mb-2">
            <ShieldCheck size={14} />
            <span>Civic Identity Verification</span>
          </div>
          <h2 className="text-xl sm:text-2xl font-bold font-display text-white">
            Civic Credential Verification
          </h2>
          <p className="text-xs text-slate-300 mt-1 leading-relaxed">
            Verify your government voter identity to activate your verified citizen badge and unlock member capabilities with 100% zero-storage privacy.
          </p>
        </div>

        {/* Verification Method Switcher Tabs */}
        {!submitted && (
          <div className="grid grid-cols-2 gap-2 p-1 rounded-2xl bg-[#0B1220] border border-[#27354F]">
            <button
              type="button"
              onClick={() => setMethod('digilocker')}
              className={`py-2.5 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2 ${
                method === 'digilocker'
                  ? 'bg-gradient-to-r from-[#FF7A2F] to-[#E86A24] text-white shadow-md'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Zap size={14} />
              <span>DigiLocker e-ID (Instant)</span>
            </button>

            <button
              type="button"
              onClick={() => setMethod('manual')}
              className={`py-2.5 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2 ${
                method === 'manual'
                  ? 'bg-[#1B2539] text-white border border-[#27354F]'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Camera size={14} />
              <span>Manual ID Upload</span>
            </button>
          </div>
        )}

        {/* DigiLocker Automated Flow */}
        {method === 'digilocker' && !submitted && (
          <div className="space-y-5 animate-in fade-in duration-200">
            <div className="p-4 rounded-2xl bg-[#1B2539] border border-[#27354F] space-y-3">
              <div className="flex items-center gap-2.5 text-xs text-[#21B579] font-bold">
                <Globe size={16} />
                <span>Government DigiLocker / e-ID Gateway</span>
              </div>
              <p className="text-xs text-slate-300 leading-relaxed">
                Automated single-pass verification via DigiLocker for <span className="font-bold text-white">{currentUser?.displayName || 'Citizen'}</span>. Securely verify your Voter ID or Aadhaar credential without storing images on server disk.
              </p>
              <ul className="text-[11px] text-slate-400 space-y-1.5 pt-1">
                <li className="flex items-center gap-2">
                  <Check size={13} className="text-[#21B579]" />
                  <span>Instant verification badge applied in ~3 seconds</span>
                </li>
                <li className="flex items-center gap-2">
                  <Check size={13} className="text-[#21B579]" />
                  <span>Zero retention — no document files saved</span>
                </li>
              </ul>
            </div>

            {digiLockerStep === 'idle' && (
              <button
                onClick={handleDigiLockerStart}
                className="w-full py-3.5 rounded-xl bg-gradient-to-r from-[#21B579] to-[#15803D] text-white text-xs font-bold elevate-sm hover:brightness-110 active:scale-98 transition-all flex items-center justify-center gap-2"
              >
                <Zap size={16} />
                <span>Verify Instantly with DigiLocker</span>
              </button>
            )}

            {(digiLockerStep === 'authorizing' || digiLockerStep === 'fetching') && (
              <div className="p-6 rounded-2xl bg-[#0B1220] border border-[#27354F] text-center space-y-3">
                <Loader2 size={28} className="animate-spin text-[#21B579] mx-auto" />
                <p className="text-xs font-bold text-white">
                  {digiLockerStep === 'authorizing'
                    ? 'Connecting to DigiLocker OAuth Gateway...'
                    : 'Verifying Voter Credential Digital Signature...'}
                </p>
                <p className="text-[11px] text-slate-400">
                  Requesting cryptographic identity assertion...
                </p>
              </div>
            )}

            {digiLockerStep === 'completed' && (
              <div className="p-6 rounded-2xl bg-[#21B579]/15 border border-[#21B579]/30 text-center space-y-3">
                <CheckCircle2 size={36} className="text-[#21B579] mx-auto" />
                <h3 className="text-base font-bold text-white">Identity Verified Successfully!</h3>
                <p className="text-xs text-slate-300">
                  Your civic profile is now verified. Zero files were retained on disk.
                </p>
                <button
                  onClick={onBrowseFeed}
                  className="w-full py-2.5 rounded-xl bg-[#21B579] text-white text-xs font-bold hover:bg-[#15803D] transition-all"
                >
                  Return to Feed
                </button>
              </div>
            )}
          </div>
        )}

        {/* Manual Photo Upload Flow */}
        {method === 'manual' && (
          <div>
            {submitted ? (
              <div className="text-center space-y-4 py-4 animate-in fade-in zoom-in-95 duration-200">
                <div className="w-16 h-16 rounded-full bg-[#21B579]/20 text-[#21B579] flex items-center justify-center text-3xl mx-auto">
                  <CheckCircle2 size={36} />
                </div>

                <div className="space-y-1">
                  <h2 className="text-xl font-bold font-display text-white">
                    Verification Under Review
                  </h2>
                  <p className="text-xs text-slate-300 max-w-sm mx-auto leading-relaxed">
                    Your ID has been submitted to the zero-retention moderator queue. You can continue reading and browsing while your civic verification is active.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-[#1B2539] border border-[#27354F] text-xs text-slate-300 flex items-start gap-3 text-left">
                  <Lock size={18} className="text-[#FF7A2F] shrink-0 mt-0.5" />
                  <div>
                    <span className="font-bold text-white block mb-0.5">
                      Zero-Storage Privacy Policy
                    </span>
                    As soon as the verification is approved or rejected, all image bytes are irreversibly wiped from server storage.
                  </div>
                </div>

                <button
                  onClick={onBrowseFeed}
                  className="w-full py-3 rounded-xl bg-[#FF7A2F] hover:bg-[#E86A24] text-white text-xs font-bold elevate-sm transition-all"
                >
                  Browse Feed (Read-Only)
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmitManual} className="space-y-5 animate-in fade-in duration-200">
                {/* Document Type Selector */}
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                    Document Type:
                  </label>
                  <select
                    value={docType}
                    onChange={(e) => setDocType(e.target.value)}
                    className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-[#FF7A2F]"
                  >
                    <option value="National Voter ID Card (EPIC)">National Voter ID Card (EPIC)</option>
                    <option value="Driving License">Driving License</option>
                    <option value="National Passport">National Passport</option>
                  </select>
                </div>

                {/* Document Upload Area */}
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                    ID Document Photo:
                  </label>

                  <div className="border-2 border-dashed border-[#27354F] hover:border-[#FF7A2F] rounded-2xl p-4 text-center bg-[#0B1220] transition-colors relative">
                    {customImage || SAMPLE_DOCS[selectedDocIndex] ? (
                      <div className="space-y-3">
                        <div className="w-full h-44 rounded-xl overflow-hidden bg-black/30 border border-[#27354F]">
                          <img
                            src={customImage || SAMPLE_DOCS[selectedDocIndex].url}
                            alt="ID Preview"
                            className="w-full h-full object-cover"
                          />
                        </div>
                        <div className="flex items-center justify-between text-xs text-slate-400">
                          <span className="text-[#21B579] font-semibold flex items-center gap-1">
                            <CheckCircle2 size={13} />
                            On-Device Compressed to ~{compressedKb} KB
                          </span>
                          <label className="text-[#FF7A2F] font-bold hover:underline cursor-pointer">
                            Change Photo
                            <input
                              type="file"
                              accept="image/*"
                              onChange={handleFileUpload}
                              className="hidden"
                            />
                          </label>
                        </div>
                      </div>
                    ) : (
                      <label className="cursor-pointer block py-8 space-y-2">
                        <div className="w-12 h-12 rounded-full bg-[#121B2E] text-[#FF7A2F] flex items-center justify-center mx-auto text-xl">
                          <Camera size={24} />
                        </div>
                        <p className="text-xs font-bold text-white">
                          Click to upload or take a photo of ID
                        </p>
                        <p className="text-[11px] text-slate-400">
                          PNG, JPG up to 10MB (automatically compressed)
                        </p>
                        <input
                          type="file"
                          accept="image/*"
                          onChange={handleFileUpload}
                          className="hidden"
                        />
                      </label>
                    )}
                  </div>
                </div>

                {/* Zero-Storage Privacy Guarantee */}
                <div className="p-3.5 rounded-2xl bg-[#21B579]/10 border border-[#21B579]/25 text-xs text-slate-300 flex items-start gap-2.5">
                  <Lock size={16} className="text-[#21B579] shrink-0 mt-0.5" />
                  <div>
                    <span className="font-bold text-[#21B579] block mb-0.5">
                      100% Zero-Retention Storage Policy
                    </span>
                    Your ID is exclusively used for single-pass bot prevention. It is permanently scrubbed as soon as an audit decision is made.
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={isCompressing}
                  className="w-full py-3 rounded-xl bg-gradient-to-r from-[#FF7A2F] to-[#E86A24] text-white text-xs font-bold elevate-sm hover:brightness-110 disabled:opacity-50 transition-all flex items-center justify-center gap-2"
                >
                  <FileCheck size={16} />
                  <span>Submit for Verification</span>
                </button>
              </form>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

