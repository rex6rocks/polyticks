// ─────────────────────────────────────────────
//  Polyticks V4.0 – Org Tier Badge (Gold Verification Badge)
// ─────────────────────────────────────────────
//
//  Renders the paid-org verification badge next to org names.
//  Tier derives from SubscriptionService/active_org_tier — never from
//  profiles.role — so plan changes require no role surgery.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/subscription_service.dart';

class OrgTierBadge extends StatelessWidget {
  final OrgTier tier;
  final bool compact;

  const OrgTierBadge({super.key, required this.tier, this.compact = false});

  @override
  Widget build(BuildContext context) {
    switch (tier) {
      case OrgTier.gold:
        return _build(const Color(0xFFD4AF37), 'GOLD', Icons.workspace_premium_rounded);
      case OrgTier.platinum:
        return _build(const Color(0xFF9FB4C7), 'PLATINUM', Icons.verified_rounded);
      case OrgTier.basic:
        return const SizedBox.shrink();
    }
  }

  Widget _build(Color color, String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 11 : 13),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.inter(
                  color: color,
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

/// Convenience wrapper for post-card author rows: fetches the tier once.
class FutureOrgTierBadge extends StatelessWidget {
  final String orgId;
  final bool compact;
  const FutureOrgTierBadge(
      {super.key, required this.orgId, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OrgTier>(
      future: SubscriptionService.fetchActiveTier(orgId),
      builder: (_, snap) =>
          OrgTierBadge(tier: snap.data ?? OrgTier.basic, compact: compact),
    );
  }
}
