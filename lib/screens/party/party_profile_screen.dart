// ─────────────────────────────────────────────
//  Polyticks – Party Profile Screen
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../../widgets/poll_widget.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/party_membership_service.dart';

class PartyProfileScreen extends StatefulWidget {
  final String partyId;
  final AppUser currentUser;

  const PartyProfileScreen({
    super.key,
    required this.partyId,
    required this.currentUser,
  });

  @override
  State<PartyProfileScreen> createState() => _PartyProfileScreenState();
}

class _PartyProfileScreenState extends State<PartyProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Auto-follow: members always follow their own party (2.a) and cannot
    // unfollow while a member — enforced again in [_toggleFollow].
    if (widget.currentUser.role == UserRole.partyMember &&
        widget.currentUser.partyId == widget.partyId) {
      mockFollowers.putIfAbsent(widget.partyId, () => []);
      if (!mockFollowers[widget.partyId]!.contains(widget.currentUser.id)) {
        mockFollowers[widget.partyId]!.add(widget.currentUser.id);
      }
    }
    _isFollowing =
        (mockFollowers[widget.partyId] ?? []).contains(widget.currentUser.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Party? get _party => partyById(widget.partyId);

  List<Post> get _partyPosts =>
      mockPosts.where((p) => p.partyId == widget.partyId).toList();

  List<Poll> get _partyPolls =>
      mockPolls.where((p) => p.partyId == widget.partyId).toList();

  bool get _canAccessPolls =>
      widget.currentUser.role == UserRole.partyMember &&
      widget.currentUser.partyId == widget.partyId;

  void _toggleFollow() {
    if (widget.currentUser.role == UserRole.party) return;
    // Members auto-follow their own party and cannot unfollow it (2.a).
    if (widget.currentUser.role == UserRole.partyMember &&
        widget.currentUser.partyId == widget.partyId) {
      return;
    }
    setState(() {
      final followers = mockFollowers[widget.partyId] ??= [];
      if (_isFollowing) {
        followers.remove(widget.currentUser.id);
      } else {
        followers.add(widget.currentUser.id);
      }
      _isFollowing = !_isFollowing;
    });
  }

  Color _parseHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final party = _party;
    if (party == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Party')),
        body: const Center(child: Text('Party not found')),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.deepNavy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildPartyBanner(party),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildPartyInfo(party),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.saffron,
                indicatorWeight: 3,
                labelColor: AppTheme.saffron,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 14),
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Polls'),
                  Tab(text: 'Members'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── Posts tab ───────────────────────────────
            ListView(
              padding: const EdgeInsets.all(12),
              children: _partyPosts.isEmpty
                  ? [_emptyState('No posts yet')]
                  : _partyPosts
                      .map((p) => PostCard(
                            key: ValueKey(p.id),
                            post: p,
                            currentUser: widget.currentUser,
                          ).animate().fadeIn(duration: 400.ms))
                      .toList(),
            ),

            // ── Polls tab ───────────────────────────────
            _canAccessPolls
                ? ListView(
                    padding: const EdgeInsets.all(12),
                    children: _partyPolls.isEmpty
                        ? [_emptyState('No polls yet')]
                        : _partyPolls
                            .map((poll) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: PollWidget(
                                    poll: poll,
                                    currentUser: widget.currentUser,
                                  ),
                                ))
                            .toList(),
                  )
                : _buildPollsLocked(party),

            // ── Members tab (#6) ────────────────────────
            _buildMembersTab(party),
          ],
        ),
      ),
    );
  }

  // ── Members tab: roster + role management + join requests ──
  List<AppUser> get _partyMembers => mockAccounts
      .map((a) => a['user'] as AppUser)
      .where((u) =>
          u.role == UserRole.partyMember && u.partyId == widget.partyId)
      .toList()
    ..sort((a, b) =>
        (a.partyRole?.tier ?? 99).compareTo(b.partyRole?.tier ?? 99));

  bool get _isOfficial =>
      widget.currentUser.role == UserRole.party &&
      widget.currentUser.partyId == widget.partyId;

  bool get _canManageRoles =>
      PartyMembershipService.canManageRoles(widget.currentUser, widget.partyId);

  List<JoinRequest> get _pendingRequests => mockJoinRequests
      .where((r) => r.partyId == widget.partyId && r.status == 'pending')
      .toList();

  JoinRequest? get _myPendingRequest {
    if (widget.currentUser.role != UserRole.janta) return null;
    for (final r in mockJoinRequests) {
      if (r.userId == widget.currentUser.id && r.status == 'pending') return r;
    }
    return null;
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.crimson : AppTheme.emerald,
    ));
  }

  void _requestMembership() {
    final result = PartyMembershipService.requestToJoin(
        widget.currentUser, widget.partyId);
    _snack(result.reason ?? 'Membership request sent to the party for approval.',
        error: !result.ok);
    setState(() {});
  }

  void _confirmLeaveParty(Party party) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyLight,
        title: Text('Leave ${party.name}?',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Your account will revert to Janta and any assigned hierarchy role '
          'will be cleared. You can request to join another party afterwards.',
          style: GoogleFonts.inter(
              color: const Color(0xFF90A4AE),
              fontSize: 13,
              height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF7C8DA6))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              PartyMembershipService.leaveParty(widget.currentUser);
              _snack('You left ${party.name}. Account reverted to Janta.');
              setState(() {});
            },
            child: const Text('Leave',
                style: TextStyle(color: AppTheme.crimson)),
          ),
        ],
      ),
    );
  }

  void _assignRoleSheet(AppUser member) {
    final takenRoles = _partyMembers
        .where((u) => u.id != member.id)
        .map((u) => u.partyRole)
        .toSet();
    showModalBottomSheet<void>(
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
              child: Text('Assign role to ${member.displayName}',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white)),
            ),
            ...PartyRole.values.map((role) {
              final topTierBlocked = role.isTopTier && !_isOfficial;
              final aboveOwnTier = !_isOfficial &&
                  widget.currentUser.partyRole != null &&
                  widget.currentUser.partyRole!.tier >= role.tier;
              final disabled =
                  topTierBlocked || aboveOwnTier || takenRoles.contains(role);
              return ListTile(
                dense: true,
                enabled: !disabled,
                title: Text(role.label,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: disabled
                            ? const Color(0xFF64748B)
                            : Colors.white)),
                subtitle: takenRoles.contains(role)
                    ? Text('Already held by another member',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF64748B)))
                    : null,
                onTap: disabled
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        final result = PartyMembershipService.assignRole(
                            member, role, widget.currentUser);
                        _snack(result.ok
                            ? '${member.displayName} is now ${role.label}.'
                            : result.reason!);
                        setState(() {});
                      },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyBanner(Party party) {
    final bannerColor = _parseHex(party.bannerColor);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bannerColor.withValues(alpha: 0.8),
            AppTheme.deepNavy,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Text(party.logoEmoji, style: const TextStyle(fontSize: 72))
            .animate()
            .scale(begin: const Offset(0.5, 0.5), duration: 500.ms),
      ),
    );
  }

  Widget _buildPartyInfo(Party party) {
    return Container(
      color: AppTheme.deepNavy,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      party.shortName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Follow button — Janta/other-party members toggle freely.
              // Members of THIS party are locked in as 'Member' (2.a).
              if (widget.currentUser.role == UserRole.partyMember &&
                  widget.currentUser.partyId == widget.partyId)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.memberColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.memberColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_user_rounded,
                        size: 14, color: AppTheme.memberColor),
                    const SizedBox(width: 6),
                    Text('Member',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.memberColor)),
                  ]),
                )
              else if (widget.currentUser.role != UserRole.party)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  child: ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isFollowing ? AppTheme.navyLight : AppTheme.saffron,
                      foregroundColor:
                          _isFollowing ? const Color(0xFF7C8DA6) : Colors.white,
                      minimumSize: const Size(100, 38),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _isFollowing
                              ? const Color(0xFF243450)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      _isFollowing ? 'Following' : 'Follow',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            party.description,
            style: GoogleFonts.inter(
                color: const Color(0xFF90A4AE), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Party accounts have no follower concept (#6)
              if (widget.currentUser.role != UserRole.party)
                Expanded(
                  child: StatChip(
                    label: 'Followers',
                    value: _formatNum((mockFollowers[party.id]?.length ?? 0) +
                        party.followerCount),
                    icon: Icons.people_alt_outlined,
                  ),
                ),
              Expanded(
                child: StatChip(
                  label: 'Members',
                  value: _formatNum(party.memberCount),
                  icon: Icons.badge_outlined,
                ),
              ),
              Expanded(
                child: StatChip(
                  label: 'Posts',
                  value: _partyPosts.length.toString(),
                  icon: Icons.article_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── My membership status (party members) — shown on the party
          // page itself so members always see which party they belong to
          // and can leave it from here.
          if (widget.currentUser.role == UserRole.partyMember) ...[
            const SizedBox(height: 12),
            if (widget.currentUser.partyId == widget.partyId)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.memberColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.memberColor.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Membership',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.memberColor)),
                    const SizedBox(height: 6),
                    Text(
                      '${party.name} (${party.shortName})'
                      '${widget.currentUser.partyRole != null ? ' · ${widget.currentUser.partyRole!.label}' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmLeaveParty(party),
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Leave Party'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.crimson,
                          side: BorderSide(
                              color:
                                  AppTheme.crimson.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.navyCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF27354F)),
                ),
                child: Text(
                  'You are already a member of '
                  '${partyById(widget.currentUser.partyId!)?.name ?? 'another party'} '
                  '(${partyById(widget.currentUser.partyId!)?.shortName ?? '?'}). '
                  'Open your own party page to leave it before applying here.',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF90A4AE),
                      height: 1.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersTab(Party party) {
    final members = _partyMembers;
    final pending = _pendingRequests;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Pending membership requests panel (#7)
        if (_canManageRoles && pending.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending membership requests (${pending.length})',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.gold)),
                const SizedBox(height: 8),
                ...pending.map((req) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(req.username,
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: Colors.white)),
                          ),
                          TextButton(
                            onPressed: () {
                              PartyMembershipService.approveJoin(req);
                              _snack('${req.username} approved as party member.');
                              setState(() {});
                            },
                            child: const Text('Approve',
                                style: TextStyle(color: AppTheme.emerald)),
                          ),
                          TextButton(
                            onPressed: () {
                              PartyMembershipService.rejectJoin(req);
                              _snack('Request rejected.');
                              setState(() {});
                            },
                            child: const Text('Reject',
                                style: TextStyle(color: AppTheme.crimson)),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Join request button for Janta visitors (#7)
        if (widget.currentUser.role == UserRole.janta) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  _myPendingRequest != null ? null : () => _requestMembership(),
              icon: Icon(_myPendingRequest != null
                  ? Icons.hourglass_top
                  : Icons.person_add_alt_1),
              label: Text(_myPendingRequest != null
                  ? 'Membership request pending'
                  : 'Request Membership'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.memberColor,
                side: BorderSide(
                    color: AppTheme.memberColor.withValues(alpha: 0.5)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        _buildMembersRoster(members),
      ],
    );
  }

  Widget _buildMembersRoster(List<AppUser> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hierarchy (${members.length})',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF7C8DA6))),
        const SizedBox(height: 8),
        if (members.isEmpty) _emptyState('No registered members yet'),
        ...members.map(_buildMemberCard),
      ],
    );
  }

  Widget _buildMemberCard(AppUser m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27354F)),
      ),
      child: Row(
        children: [
          UserAvatar(user: m, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.displayName,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 4),
                // Tags: <party abbreviation> + <hierarchy role>
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_party?.shortName != null)
                      _memberTag(_party!.shortName, AppTheme.saffron),
                    if (m.partyRole != null)
                      _memberTag(
                          m.partyRole!.label,
                          m.partyRole!.isTopTier
                              ? const Color(0xFFA78BFA)
                              : const Color(0xFF7DD3FC)),
                  ],
                ),
                Text(
                  '${(mockMemberFollowers[m.id]?.length ?? 0)} followers',
                  style: GoogleFonts.inter(
                      fontSize: 10, color: const Color(0xFF7C8DA6)),
                ),
              ],
            ),
          ),
          // Follow party members (#5) – not available to party accounts and
          // never for one's own account (no self-follow, #2).
          if (widget.currentUser.role != UserRole.party &&
              m.id != widget.currentUser.id)
            TextButton.icon(
              onPressed: () {
                final nowFollowing =
                    toggleMemberFollow(m.id, widget.currentUser.id);
                _snack(nowFollowing
                    ? 'Following ${m.displayName}.'
                    : 'Unfollowed ${m.displayName}.');
                setState(() {});
              },
              icon: Icon(
                isFollowingMember(m.id, widget.currentUser.id)
                    ? Icons.check
                    : Icons.person_add_alt_1,
                size: 14,
              ),
              label: Text(
                isFollowingMember(m.id, widget.currentUser.id)
                    ? 'Following'
                    : 'Follow',
                style: const TextStyle(fontSize: 11),
              ),
              style: TextButton.styleFrom(foregroundColor: AppTheme.saffron),
            ),
          // Role management (#3): only higher hierarchy may edit roles, and
          // nobody can change their own role/remove themselves here — a
          // president's role can only be changed from the party account.
          if (_canManageRoles && m.id != widget.currentUser.id) ...[
            IconButton(
              tooltip: 'Assign role',
              icon: const Icon(Icons.badge_outlined,
                  size: 20, color: Color(0xFF7C8DA6)),
              onPressed: () => _assignRoleSheet(m),
            ),
            if (m.partyRole != null)
              IconButton(
                tooltip: 'Revoke role',
                icon: const Icon(Icons.badge_outlined,
                    size: 20, color: AppTheme.crimson),
                onPressed: () {
                  final result =
                      PartyMembershipService.revokeRole(m, widget.currentUser);
                  _snack(result.ok ? 'Role revoked.' : result.reason!,
                      error: !result.ok);
                  setState(() {});
                },
              ),
            IconButton(
              tooltip: 'Remove from party',
              icon: const Icon(Icons.person_remove_outlined,
                  size: 20, color: AppTheme.crimson),
              onPressed: () {
                final result =
                    PartyMembershipService.removeMember(m, widget.currentUser);
                _snack(result.ok
                    ? '${m.displayName} reverted to Janta.'
                    : result.reason!);
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildPollsLocked(Party party) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.memberColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.memberColor.withValues(alpha: 0.3),
                    width: 2),
              ),
              child: const Center(
                child: Icon(Icons.lock_outline,
                    color: AppTheme.memberColor, size: 36),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Members Only',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Polls are exclusive to members of ${party.name}. Sign up as a Party Member and join this party to participate.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF7C8DA6),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              party.logoEmoji,
              style: const TextStyle(fontSize: 48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message,
              style: GoogleFonts.inter(
                  color: const Color(0xFF64748B), fontSize: 14)),
        ),
      );

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.deepNavy,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}
