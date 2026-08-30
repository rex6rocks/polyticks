// ─────────────────────────────────────────────
//  Polyticks – Community Notes Section (V2)
// ─────────────────────────────────────────────
//
//  Renders the fact-check / community notes attached to a post
//  (Task A3 of the V2 completion plan). Fetches notes via
//  FactCheckService.fetchNotesForPost and displays:
//    * context note text + author
//    * source links as tappable URLs
//    * upvote / downvote counts with verified-only vote + retract actions

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/exceptions.dart';
import '../services/fact_check_service.dart';

class CommunityNotesSection extends StatefulWidget {
  final String postId;
  final bool viewerCanVote; // verified-only gating decided by the caller

  const CommunityNotesSection({
    super.key,
    required this.postId,
    required this.viewerCanVote,
  });

  @override
  State<CommunityNotesSection> createState() => _CommunityNotesSectionState();
}

class _CommunityNotesSectionState extends State<CommunityNotesSection> {
  late Future<List<Map<String, dynamic>>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _notesFuture = FactCheckService.instance.fetchNotesForPost(widget.postId);
  }

  void _reload() {
    setState(() {
      _notesFuture = FactCheckService.instance.fetchNotesForPost(widget.postId);
    });
  }

  Future<void> _vote(String noteId, String voteType) async {
    try {
      await FactCheckService.instance
          .voteOnNote(noteId: noteId, voteType: voteType);
      _reload();
    } on PolyticksDomainException catch (e) {
      _showFriendly(e.userFriendlyMessage);
    } catch (_) {
      _showFriendly('Could not record your vote. Please try again.');
    }
  }

  Future<void> _retract(String noteId) async {
    try {
      await FactCheckService.instance.retractVote(noteId: noteId);
      _reload();
    } on PolyticksDomainException catch (e) {
      _showFriendly(e.userFriendlyMessage);
    } catch (_) {
      _showFriendly('Could not retract your vote. Please try again.');
    }
  }

  void _showFriendly(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _notesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final notes = snapshot.data ?? const [];
        if (notes.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check_outlined,
                      color: Color(0xFF64B5F6), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Community Notes (${notes.length})',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF90CAF9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...notes.map(_buildNote),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNote(Map<String, dynamic> note) {
    final author =
        (note['profiles'] as Map<String, dynamic>?)?['username'] ?? 'Verified contributor';
    final sources = (note['source_links'] as List?)?.cast<String>() ?? const [];
    final upvotes = note['upvotes'] ?? 0;
    final downvotes = note['downvotes'] ?? 0;

    // Determine the viewer's existing vote from the embedded vote map.
    final votes = (note['fact_check_votes'] as List?) ?? const [];
    final myVote = votes
        .whereType<Map<String, dynamic>>()
        .map((v) => v['vote_type'] as String?)
        .firstWhere((t) => t != null, orElse: () => null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$author · verified context note',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF7C8DA6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note['context_note']?.toString() ?? '',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white, height: 1.4),
          ),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: sources.map((s) {
                return GestureDetector(
                  onTap: () => _openSource(s),
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64B5F6),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              _VoteButton(
                icon: Icons.thumb_up_alt_outlined,
                count: upvotes,
                active: myVote == 'upvote',
                enabled: widget.viewerCanVote,
                onTap: () => _vote(note['id'] as String, 'upvote'),
              ),
              const SizedBox(width: 12),
              _VoteButton(
                icon: Icons.thumb_down_alt_outlined,
                count: downvotes,
                active: myVote == 'downvote',
                enabled: widget.viewerCanVote,
                onTap: () => _vote(note['id'] as String, 'downvote'),
              ),
              if (widget.viewerCanVote && myVote != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _retract(note['id'] as String),
                  child: Text(
                    'Retract vote',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF7C8DA6),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final dynamic count;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.count,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF4FC3F7) : const Color(0xFF7C8DA6);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: enabled ? color : color.withValues(alpha: 0.4)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: GoogleFonts.inter(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
