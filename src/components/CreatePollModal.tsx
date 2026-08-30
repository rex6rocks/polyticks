import React, { useState } from 'react';
import { Party, AppUser, Poll } from '../types';
import { X, Plus, Trash2 } from 'lucide-react';

interface CreatePollModalProps {
  party: Party;
  currentUser?: AppUser;
  onClose: () => void;
  onCreate: (poll: Poll) => void;
}

export const CreatePollModal: React.FC<CreatePollModalProps> = ({
  party,
  onClose,
  onCreate,
}) => {
  const [question, setQuestion] = useState('');
  const [description, setDescription] = useState('');
  const [options, setOptions] = useState<string[]>(['', '']);

  const handleAddOption = () => {
    if (options.length < 6) {
      setOptions([...options, '']);
    }
  };

  const handleRemoveOption = (index: number) => {
    if (options.length > 2) {
      setOptions(options.filter((_, i) => i !== index));
    }
  };

  const handleOptionChange = (index: number, value: string) => {
    const updated = [...options];
    updated[index] = value;
    setOptions(updated);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const validOptions = options.map((o) => o.trim()).filter((o) => o.length > 0);
    if (!question.trim() || validOptions.length < 2) return;

    const newPoll: Poll = {
      id: `poll-${Date.now()}`,
      partyId: party.id,
      question: question.trim(),
      options: validOptions.map((text, idx) => ({
        id: `opt-${idx + 1}`,
        text,
        votes: 0,
      })),
      totalVotes: 0,
      endsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    };

    onCreate(newPoll);
  };

  const isValid = question.trim().length > 0 && options.filter((o) => o.trim().length > 0).length >= 2;

  return (
    <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="bg-[#121B2E] border border-[#27354F] rounded-3xl max-w-lg w-full p-6 shadow-2xl relative overflow-hidden">
        <div className="flex items-center justify-between pb-4 border-b border-[#27354F]">
          <div className="flex items-center space-x-2">
            <div className="w-9 h-9 rounded-xl bg-[#FF7A2F]/20 border border-[#FF7A2F]/30 flex items-center justify-center text-lg">
              📊
            </div>
            <div>
              <h3 className="text-base font-bold text-white">Create Official Poll</h3>
              <p className="text-xs text-slate-400">Post a poll for party members and civic audience</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-[#1B2539] transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="mt-4 space-y-4">
          <div>
            <label className="block text-xs font-bold text-slate-300 mb-1">
              Poll Question <span className="text-[#FF7A2F]">*</span>
            </label>
            <input
              type="text"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              placeholder="e.g., Should we prioritize urban infrastructure in manifesto?"
              className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-[#FF7A2F]"
              required
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-300 mb-1">
              Description / Context (Optional)
            </label>
            <textarea
              rows={2}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Brief context or background for voters..."
              className="w-full bg-[#0B1220] border border-[#27354F] rounded-xl p-3 text-xs text-white focus:outline-none focus:border-[#FF7A2F] resize-none"
            />
          </div>

          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="text-xs font-bold text-slate-300">
                Poll Options (2 - 6 options) <span className="text-[#FF7A2F]">*</span>
              </label>
              {options.length < 6 && (
                <button
                  type="button"
                  onClick={handleAddOption}
                  className="text-xs text-[#FF7A2F] hover:underline flex items-center space-x-1 font-semibold"
                >
                  <Plus size={12} />
                  <span>Add Option</span>
                </button>
              )}
            </div>

            <div className="space-y-2">
              {options.map((opt, idx) => (
                <div key={idx} className="flex items-center space-x-2">
                  <input
                    type="text"
                    value={opt}
                    onChange={(e) => handleOptionChange(idx, e.target.value)}
                    placeholder={`Option ${idx + 1}`}
                    className="flex-1 bg-[#0B1220] border border-[#27354F] rounded-xl px-3 py-2 text-xs text-white focus:outline-none focus:border-[#FF7A2F]"
                  />
                  {options.length > 2 && (
                    <button
                      type="button"
                      onClick={() => handleRemoveOption(idx)}
                      className="p-2 text-slate-400 hover:text-red-400 transition-colors"
                    >
                      <Trash2 size={14} />
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>

          <div className="pt-2 flex items-center justify-end space-x-3 border-t border-[#27354F]">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl bg-[#1B2539] text-slate-300 font-semibold text-xs hover:bg-[#27354F] transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!isValid}
              className="px-5 py-2 rounded-xl bg-[#FF7A2F] text-white font-bold text-xs hover:bg-[#E86A24] transition-colors disabled:opacity-50 shadow-md shadow-orange-500/20"
            >
              Create Poll
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
