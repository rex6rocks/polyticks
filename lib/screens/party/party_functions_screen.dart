// ─────────────────────────────────────────────
//  Polyticks – Party Functions Screen (#6)
//  Right-of-reply · member requests · org chart
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../services/party_membership_service.dart';
import '../org/right_of_reply_portal.dart';
import '../../widgets/shared_widgets.dart';

class PartyFunctionsScreen extends StatefulWidget {
  final AppUser currentUser;
  const PartyFunctionsScreen({super.key, required this.currentUser});

  @override
  State<PartyFunctionsScreen> createState() => _PartyFunctionsScreenState();
}

class _PartyFunctionsScreenState extends State<PartyFunctionsScreen> {
  String _section = 'requests'; // requests | orgchart

  String get _partyId =>
      widget.currentUser.partyId ?? mockParties.first.id;

  List<AppUser> get _members => mockAccounts
      .map((a) => a['user'] as AppUser)
      .where((u) => u.role == UserRole.partyMember && u.partyId == _partyId)
      .toList()
    ..sort((a, b) =>
        (a.partyRole?.tier ?? 99).compareTo(b.partyRole?.tier ?? 99));

  List<JoinRequest> get _pending => mockJoinRequests
      .where((r) => r.partyId == _partyId && r.status == 'pending')
      .toList();

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.crimson : AppTheme.emerald,
    ));
  }

  /// Org-chart role change with confirmation prompt.
  Future<void> _changeRole(AppUser member) async {
    final taken = _members.where((m) => m.id != member.id).map((m) => m.partyRole).toSet();
    PartyRole? selected;
    final picked = await showModalBottomSheet<PartyRole>(
      context: context,
      backgroundColor: AppTheme.navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Text('Change role – ${member.displayName}',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white)),
            ),
            ...PartyRole.values.map((role) {
              final disabled = role.isTopTier && widget.currentUser.role != UserRole.party ||
                  taken.contains(role);
              return ListTile(
                dense: true,
                enabled: !disabled,
                title: Text(role.label,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color:
                            disabled ? const Color(0xFF64748B) : Colors.white)),
                trailing: member.partyRole == role
                    ? const Icon(Icons.check, size: 16, color: AppTheme.saffron)
                    : null,
                onTap: disabled ? null : () => Navigator.pop(ctx, role),
              );
            }),
          ],
        ),
      ),
    );
    if (picked == null || picked == member.partyRole) return;

    // Confirmation prompt before applying the change.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        title: Text('Confirm role change',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        content: Text(
          'Change ${member.displayName}\'s role to "${picked.label}"?',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFB0BEC5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF7C8DA6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm change',
                style: TextStyle(color: AppTheme.saffron)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (member.partyRole != null) {
      PartyMembershipService.revokeRole(member, widget.currentUser);
    }
    final result =
        PartyMembershipService.assignRole(member, picked, widget.currentUser);
    _snack(result.ok
        ? '${member.displayName} is now ${picked.label}.'
        : result.reason!, error: !result.ok);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        title: Text('Party Functions',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => setState(() => _section = 'requests'),
            child: Text('Requests (${_pending.length})',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _section == 'requests'
                        ? AppTheme.saffron
                        : const Color(0xFF7C8DA6))),
          ),
          TextButton(
            onPressed: () => setState(() => _section = 'orgchart'),
            child: Text('Org Chart',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _section == 'orgchart'
                        ? AppTheme.saffron
                        : const Color(0xFF7C8DA6))),
          ),
        ],
      ),
      body: _section == 'requests'
          ? _buildRequests()
          : Column(children: [
              Expanded(child: _buildOrgChart()),
              // Right-of-Reply portal access card
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.gavel_rounded,
                        color: AppTheme.saffron),
                    title: Text('Right of Reply Portal',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white)),
                    subtitle: Text(
                        'Respond to fact-checks and community notes on party posts',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF7C8DA6))),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFF7C8DA6)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RightOfReplyPortal(currentUser: widget.currentUser),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _buildRequests() {
    if (_pending.isEmpty) {
      return Center(
        child: Text('No pending membership requests.',
            style: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFF7C8DA6))),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _pending
          .map((req) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.navyLight,
                    child: Text(req.username.isNotEmpty
                        ? req.username[0]
                        : '?'),
                  ),
                  title: Text(req.username,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.white)),
                  subtitle: Text('wants to join your party',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: const Color(0xFF7C8DA6))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Approve',
                        icon: const Icon(Icons.check_circle_outline,
                            color: AppTheme.emerald),
                        onPressed: () {
                          PartyMembershipService.approveJoin(req);
                          _snack('${req.username} approved as party member.');
                          setState(() {});
                        },
                      ),
                      IconButton(
                        tooltip: 'Reject',
                        icon: const Icon(Icons.cancel_outlined,
                            color: AppTheme.crimson),
                        onPressed: () {
                          PartyMembershipService.rejectJoin(req);
                          _snack('Request rejected.');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  /// Tier-grouped org chart with on-the-spot role changes.
  Widget _buildOrgChart() {
    final groups = <int, List<AppUser>>{};
    for (final m in _members) {
      groups.putIfAbsent(m.partyRole?.tier ?? 99, () => []).add(m);
    }
    final tiers = groups.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final tier in tiers) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
            child: Text(
              tier == 99
                  ? 'Members without role'
                  : groups[tier]!.first.partyRole!.label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: const Color(0xFF7C8DA6)),
            ),
          ),
          ...groups[tier]!.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.navyCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF27354F)),
                ),
                child: Row(
                  children: [
                    UserAvatar(user: m, radius: 15),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(m.displayName,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white)),
                    ),
                    ActionChip(
                      label: Text(m.partyRole?.label ?? 'Assign role',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: m.partyRole != null
                                  ? Colors.white
                                  : AppTheme.saffron)),
                      backgroundColor: m.partyRole != null
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppTheme.saffron.withValues(alpha: 0.1),
                      side: BorderSide(
                          color: m.partyRole != null
                              ? const Color(0xFF27354F)
                              : AppTheme.saffron.withValues(alpha: 0.4)),
                      onPressed: () => _changeRole(m),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}
