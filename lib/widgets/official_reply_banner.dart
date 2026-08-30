// ─────────────────────────────────────────────
//  Polyticks V4.0 – Official Reply Banner (B11)
// ─────────────────────────────────────────────
//
//  Public "Right of Reply" display: renders an organization's published
//  official statement beneath a disputed / under-review post.
//  Fetches only published replies (RLS: public read on published).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/right_of_reply_service.dart';
import '../theme/app_theme.dart';

class OfficialReplyBanner extends StatelessWidget {
  final String postId;

  const OfficialReplyBanner({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OfficialReply?>(
      future: RightOfReplyService.fetchPublishedForPost(postId),
      builder: (context, snap) {
        final reply = snap.data;
        if (reply == null || !reply.isPublished) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.saffron.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppTheme.saffron.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: AppTheme.saffron, size: 15),
                const SizedBox(width: 6),
                Text('OFFICIAL RESPONSE',
                    style: GoogleFonts.inter(
                        color: AppTheme.saffron,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ]),
              const SizedBox(height: 6),
              Text(reply.statement,
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 12.5, height: 1.55)),
            ],
          ),
        );
      },
    );
  }
}
