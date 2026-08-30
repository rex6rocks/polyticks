// ─────────────────────────────────────────────
//  Polyticks – Under Review Banner Widget
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

class UnderReviewBanner extends StatelessWidget {
  final FactCheckStatus status;
  final String? customMessage;
  final VoidCallback? onAddContext;
  final bool canAddContext;

  const UnderReviewBanner({
    super.key,
    required this.status,
    this.customMessage,
    this.onAddContext,
    this.canAddContext = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status == FactCheckStatus.none) {
      return const SizedBox.shrink();
    }

    final isDisputed = status == FactCheckStatus.disputed;
    final isVerifiedContext = status == FactCheckStatus.verifiedContext;
    final isUnderReview = status == FactCheckStatus.underReview;

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String defaultTitle;

    if (isDisputed) {
      bgColor = const Color(0xFFEF5350).withValues(alpha: 0.15);
      borderColor = const Color(0xFFEF5350).withValues(alpha: 0.4);
      textColor = const Color(0xFFFF8A80);
      icon = Icons.error_outline_rounded;
      defaultTitle = 'Content Disputed by Community';
    } else if (isVerifiedContext) {
      bgColor = const Color(0xFF66BB6A).withValues(alpha: 0.15);
      borderColor = const Color(0xFF66BB6A).withValues(alpha: 0.4);
      textColor = const Color(0xFFA5D6A7);
      icon = Icons.verified_user_outlined;
      defaultTitle = 'Verified Community Context Attached';
    } else {
      // Under Review / Auto-Hidden
      bgColor = const Color(0xFFFFB74D).withValues(alpha: 0.15);
      borderColor = const Color(0xFFFFB74D).withValues(alpha: 0.4);
      textColor = const Color(0xFFFFCC80);
      icon = Icons.warning_amber_rounded;
      defaultTitle = isUnderReview ? 'This post is currently under review' : 'Content temporarily auto-hidden';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  defaultTitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (canAddContext && onAddContext != null)
                InkWell(
                  onTap: onAddContext,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Add Context',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4FC3F7),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (customMessage != null && customMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              customMessage!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
