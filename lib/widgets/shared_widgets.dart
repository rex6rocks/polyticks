// ─────────────────────────────────────────────
//  Polyticks – Reusable Widgets
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────
//  Role Badge
// ─────────────────────────────────────────────
class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool small;
  const RoleBadge({super.key, required this.role, this.small = false});

  String get _label {
    switch (role) {
      case UserRole.janta:
        return 'Janta';
      case UserRole.party:
        return 'Party';
      case UserRole.partyMember:
        return 'Member';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Color get _color {
    switch (role) {
      case UserRole.janta:
        return AppTheme.jantaColor;
      case UserRole.party:
        return AppTheme.partyColor;
      case UserRole.partyMember:
        return AppTheme.memberColor;
      case UserRole.admin:
        return AppTheme.adminColor;
    }
  }

  IconData get _icon {
    switch (role) {
      case UserRole.janta:
        return Icons.people_alt_outlined;
      case UserRole.party:
        return Icons.account_balance_outlined;
      case UserRole.partyMember:
        return Icons.badge_outlined;
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = small ? 10.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: size),
          SizedBox(width: small ? 3 : 4),
          Text(
            _label,
            style: GoogleFonts.inter(
              fontSize: size,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  User Avatar
// ─────────────────────────────────────────────
class UserAvatar extends StatelessWidget {
  final AppUser user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 20});

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (user.avatarUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(user.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: _parseColor(user.avatarColor),
      child: Text(
        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
        style: GoogleFonts.inter(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Stat Chip (for party profile)
// ─────────────────────────────────────────────
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const StatChip({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.saffron, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white)),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF7C8DA6))),
      ],
    );
  }
}
