// ─────────────────────────────────────────────
//  Polyticks – Poll Widget
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../providers/poll_provider.dart';

class PollWidget extends ConsumerStatefulWidget {
  final Poll poll;
  final AppUser currentUser;

  const PollWidget({super.key, required this.poll, required this.currentUser});

  @override
  ConsumerState<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends ConsumerState<PollWidget> {
  bool get _canVote =>
      widget.currentUser.role == UserRole.partyMember &&
      widget.currentUser.partyId == widget.poll.partyId &&
      widget.currentUser.isVerified;

  bool get _isResultsMode {
    final poll = ref.watch(pollProvider(widget.poll));
    return poll.votedOptionId != null ||
        !widget.currentUser.isVerified ||
        !_canVote;
  }

  Future<void> _vote(String optionId) async {
    if (!_canVote || ref.read(pollProvider(widget.poll)).votedOptionId != null) return;
    final ok = await ref.read(pollProvider(widget.poll).notifier).vote(optionId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SupabaseService.pollVoteFailureMessage)),
      );
    }
  }

  String _timeLeft(Poll poll) {
    final diff = poll.endsAt.difference(DateTime.now());
    if (diff.isNegative) return 'Ended';
    if (diff.inDays > 0) return '${diff.inDays}d left';
    if (diff.inHours > 0) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }

  @override
  Widget build(BuildContext context) {
    final poll = ref.watch(pollProvider(widget.poll)); final totalVotes = poll.totalVotes;

    return Card(
      color: AppTheme.navyCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.saffron.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.how_to_vote_outlined,
                          color: AppTheme.saffron, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Community Poll',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.saffron,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.currentUser.isVerified) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Unverified (Results Mode)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.amber,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      _timeLeft(poll),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Question ─────────────────────────────────
            Text(
              poll.question,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            // ── Options ───────────────────────────────────
            ...poll.options.map((option) {
              final isVotedOption = poll.votedOptionId == option.id;
              final double ratio =
                  totalVotes > 0 ? (option.votes / totalVotes) : 0.0;
              final double pct = ratio * 100;

              return Padding(
                key: ValueKey(option.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: _isResultsMode ? null : () => _vote(option.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isVotedOption
                          ? AppTheme.saffron.withValues(alpha: 0.15)
                          : AppTheme.navyLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isVotedOption
                            ? AppTheme.saffron
                            : Colors.white.withValues(alpha: 0.1),
                        width: isVotedOption ? 1.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        children: [
                          // ── Animated Progress Indicator in Results Mode ──
                          if (_isResultsMode)
                            Positioned.fill(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: ratio),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isVotedOption
                                          ? AppTheme.saffron.withValues(alpha: 0.25)
                                          : Colors.white.withValues(alpha: 0.08),
                                    ),
                                    minHeight: double.infinity,
                                  );
                                },
                              ),
                            ),

                          // ── Option Text & Percentage Overlay ───────────
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.text,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: isVotedOption
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isVotedOption
                                          ? Colors.white
                                          : const Color(0xFFCFD8DC),
                                    ),
                                  ),
                                ),
                                if (_isResultsMode) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${pct.toStringAsFixed(1)}%',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isVotedOption
                                          ? AppTheme.saffron
                                          : const Color(0xFF90A4AE),
                                    ),
                                  ),
                                ],
                                if (isVotedOption) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppTheme.saffron, size: 16),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms);
            }),

            const SizedBox(height: 6),

            // ── Footer Info ───────────────────────────────
            Row(
              children: [
                Text(
                  '$totalVotes total votes',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF7C8DA6)),
                ),
                const Spacer(),
                if (!widget.currentUser.isVerified)
                  Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 13, color: AppTheme.amber),
                      const SizedBox(width: 4),
                      Text(
                        'Verify identity to vote',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.amber),
                      ),
                    ],
                  )
                else if (!_canVote && poll.votedOptionId == null)
                  Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 13, color: Color(0xFF7C8DA6)),
                      const SizedBox(width: 4),
                      Text(
                        'Party Members only',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFF7C8DA6)),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
