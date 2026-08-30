//
// community_note_card.dart
//
// Stateless widget to display community fact-check notes below post content.
//

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityNoteCard extends StatelessWidget {
  final String authorHandle;
  final String contextNote;
  final List<String> sources;
  final int upvotes;
  final int downvotes;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  const CommunityNoteCard({
    super.key,
    required this.authorHandle,
    required this.contextNote,
    required this.sources,
    required this.upvotes,
    required this.downvotes,
    required this.onUpvote,
    required this.onDownvote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E44),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF2A405A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF4FC3F7), size: 18),
              const SizedBox(width: 6),
              Text(
                'Community Context',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF4FC3F7),
                ),
              ),
              const Spacer(),
              Text(
                'by @$authorHandle',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF7C8DA6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Note Text
          Text(
            contextNote,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),

          // Sources
          if (sources.isNotEmpty) ...[
            Text(
              'Sources:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7C8DA6),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6.0,
              runSpacing: 4.0,
              children: sources.map((source) => _buildSourceChip(source)).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // Vote Actions
          Row(
            children: [
              _buildVoteButton(Icons.thumb_up, upvotes, const Color(0xFF66BB6A), onUpvote),
              const SizedBox(width: 12),
              _buildVoteButton(Icons.thumb_down, downvotes, const Color(0xFFEF5350), onDownvote),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceChip(String source) {
    return GestureDetector(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(source))) {
          await launchUrl(Uri.parse(source));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2A405A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 12, color: Color(0xFF4FC3F7)),
            const SizedBox(width: 4),
            Text(
              Uri.parse(source).host,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF4FC3F7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton(IconData icon, int count, Color color, VoidCallback? onPressed) {
    return Row(
      children: [
        IconButton(
          icon: Icon(icon, size: 16, color: color),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}