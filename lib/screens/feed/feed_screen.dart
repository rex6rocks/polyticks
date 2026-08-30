// ─────────────────────────────────────────────
//  Polyticks – Main Feed Screen
// ─────────────────────────────────────────────
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';

import '../../widgets/shared_widgets.dart';
import '../../widgets/post_card.dart';
import '../../widgets/community_selector_dialog.dart';
import '../../widgets/create_post_modal.dart';
import '../party/party_profile_screen.dart';
import '../auth/verification_status_screen.dart';
import '../party/party_functions_screen.dart';
import '../admin/admin_console_screen.dart';
import '../org/subscription_screen.dart';
import '../org/analytics_dashboard.dart';
import '../org/right_of_reply_portal.dart';

class FeedScreen extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onLogout;

  const FeedScreen({
    super.key,
    required this.currentUser,
    required this.onLogout,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  int _currentTab = 0;
  int _feedSubTab =
      0; // 0: Hyper-Local (My Community), 1: Broader Channel (National)
  bool _showGreeting = true;
  bool _isLoadingFeed = false;
  late AnimationController _greetController;
  late TabController _feedTabController;
  List<Post> _fetchedPosts = [];

  @override
  void initState() {
    super.initState();
    _greetController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _greetController.forward().catchError((e) {
      // Animation controller might be disposed
    }).then((_) {
      if (mounted) setState(() => _showGreeting = false);
    });

    _feedTabController = TabController(length: 2, vsync: this);
    _feedTabController.addListener(_onFeedTabChanged);

    _loadFeedPosts();
  }

  void _onFeedTabChanged() {
    if (_feedTabController.indexIsChanging) return;
    if (_feedSubTab != _feedTabController.index) {
      setState(() {
        _feedSubTab = _feedTabController.index;
      });
      _loadFeedPosts();
    }
  }

  Future<void> _loadFeedPosts() async {
    if (!mounted) return;
    if (widget.currentUser.isGuest) {
      // Guests don't have a communityId, load standard posts
      setState(() => _isLoadingFeed = true);
      final posts = await SupabaseService.instance.getPosts(hyperLocal: false);
      if (mounted) {
        setState(() {
          _fetchedPosts = posts;
          _isLoadingFeed = false;
        });
      }
      return;
    }
    setState(() => _isLoadingFeed = true);
    final isHyperLocal = _feedSubTab == 0;
    final posts = await SupabaseService.instance.getPosts(
      hyperLocal: isHyperLocal,
      communityId: widget.currentUser.communityId,
    );
    if (mounted) {
      setState(() {
        _fetchedPosts = posts;
        _isLoadingFeed = false;
      });
    }
  }


  @override
  void dispose() {
    _greetController.dispose();
    _feedTabController.removeListener(_onFeedTabChanged);
    _feedTabController.dispose();
    super.dispose();
  }

  List<Post> get _filteredPosts {
    if (_fetchedPosts.isNotEmpty) {
      return _fetchedPosts;
    }
    // Fallback logic for simulation / mock filtering
    final isHyperLocal = _feedSubTab == 0;
    final basePosts = widget.currentUser.role == UserRole.janta
        ? mockPosts.where((post) {
            if (post.type == PostType.memberPost) {
              final followers = mockFollowers[post.partyId] ?? [];
              return followers.contains(widget.currentUser.id);
            }
            return true;
          }).toList()
        : mockPosts;

    if (widget.currentUser.isGuest) {
      return basePosts.where((post) => post.channelType == ChannelType.broader).toList();
    }

    return basePosts.where((post) {
      if (isHyperLocal) {
        return post.channelType == ChannelType.hyperLocal ||
            post.communityId == widget.currentUser.communityId ||
            post.type == PostType.memberPost;
      } else {
        return post.channelType == ChannelType.broader ||
            post.communityId == null;
      }
    }).toList();
  }


  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName => widget.currentUser.displayName.split(' ').first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () {
                showCreatePostModal(
                  context,
                  currentUser: widget.currentUser,
                  onPostCreated: _loadFeedPosts,
                );
              },
              backgroundColor: AppTheme.saffron,
              elevation: 2,
              shape: const CircleBorder(),
              child:
                  const Icon(Icons.edit_square, color: Colors.black, size: 20),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final showFeedTabs = _currentTab == 0;
    return PreferredSize(
      preferredSize:
          Size.fromHeight(kToolbarHeight + (showFeedTabs ? 48.0 : 0.0)),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            backgroundColor: AppTheme.deepNavy.withValues(alpha: 0.7),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.saffron, Color(0xFFFF9E40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.saffron.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🗳️', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Polyticks',
                    style: Theme.of(context).appBarTheme.titleTextStyle),
              ],
            ),
            actions: [
              Center(
                  child: RoleBadge(role: widget.currentUser.role, small: true)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.shield_outlined,
                    color: AppTheme.saffron, size: 20),
                tooltip: 'Admin Console',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminConsoleScreen(onLogout: widget.onLogout),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showProfileMenu(context),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: UserAvatar(user: widget.currentUser, radius: 16),
                ),
              ),
            ],
            bottom: showFeedTabs
                ? TabBar(
                    controller: _feedTabController,
                    indicatorColor: AppTheme.saffron,
                    indicatorWeight: 3,
                    labelColor: AppTheme.saffron,
                    unselectedLabelColor: const Color(0xFF7C8DA6),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'Hyper-Local'),
                      Tab(text: 'Broader Channel'),
                    ],
                  )
                : null,
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          // Material (not a decorated Container) so the ListTiles below paint
          // their background/ink on this ancestor instead of one hidden behind
          // a DecoratedBox — avoids the "ink splashes may be invisible" assert.
          child: Material(
            color: AppTheme.navyCard.withValues(alpha: 0.85),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              side: BorderSide(color: Color(0x1AFFFFFF)), // white @ 0.1
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.saffron.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: UserAvatar(user: widget.currentUser, radius: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.currentUser.displayName,
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                RoleBadge(role: widget.currentUser.role),
                const SizedBox(height: 10),
                // Verification status — tappable, opens the status screen.
                GestureDetector(
                  onTap: () =>
                      _openVerificationStatus(context, widget.currentUser),
                  child: Builder(builder: (context) {
                    final (label, color, icon) =
                        _verificationVisual(widget.currentUser);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 14, color: color),
                        const SizedBox(width: 6),
                        Text(label,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ]),
                    );
                  }),
                ),
                if (widget.currentUser.partyId != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    partyById(widget.currentUser.partyId!)?.name ?? '',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF7C8DA6), fontSize: 14),
                  ),
                ],
                if (widget.currentUser.role == UserRole.janta) ...[
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: Text('Stay Anonymous',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text('Hide your name when interacting',
                        style: GoogleFonts.inter(
                            color: const Color(0xFF7C8DA6), fontSize: 12)),
                    value: widget.currentUser.isAnonymous,
                    activeThumbColor: AppTheme.saffron,
                    onChanged: (val) {
                      setModalState(() => widget.currentUser.isAnonymous = val);
                      setState(() {});
                    },
                  ),
                ],
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.saffron.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_city_rounded,
                        color: AppTheme.saffron, size: 20),
                  ),
                  title: Text('Community / Ward',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                      widget.currentUser.communityId ??
                          'Not assigned – Tap to select',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF7C8DA6), fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF7C8DA6)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showCommunitySelectorDialog(
                      context,
                      currentUser: widget.currentUser,
                      onCommunitySelected: (newCommunity) {
                        setState(() {});
                        _loadFeedPosts();
                      },
                    );
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  tileColor: Colors.white.withValues(alpha: 0.03),
                ),
                const SizedBox(height: 16),
                // V4.0 B12: org monetization + analytics entry points.
                if (widget.currentUser.role == UserRole.party ||
                    widget.currentUser.role == UserRole.partyMember) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.saffron.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded,
                          color: AppTheme.saffron, size: 20),
                    ),
                    title: Text('Organization Plans',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text('Upgrade · Gold badge · Priority broadcasts',
                        style: GoogleFonts.inter(
                            color: const Color(0xFF7C8DA6), fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF7C8DA6)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrgSubscriptionScreen(
                              currentUser: widget.currentUser),
                        ),
                      );
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    tileColor: Colors.white.withValues(alpha: 0.03),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.memberColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.query_stats_rounded,
                          color: AppTheme.memberColor, size: 20),
                    ),
                    title: Text('Campaign Analytics',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text('Reach, trust score & fact-check outcomes',
                        style: GoogleFonts.inter(
                            color: const Color(0xFF7C8DA6), fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF7C8DA6)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrgAnalyticsDashboard(
                              currentUser: widget.currentUser),
                        ),
                      );
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    tileColor: Colors.white.withValues(alpha: 0.03),
                  ),
                  const SizedBox(height: 8),
                  // B11: Right-of-Reply portal entry (paid-org perk).
                  if (widget.currentUser.role == UserRole.party) ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.memberColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.gavel_rounded,
                          color: AppTheme.memberColor, size: 20),
                    ),
                    title: Text('Right of Reply',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text('Official statements on disputed posts',
                        style: GoogleFonts.inter(
                            color: const Color(0xFF7C8DA6), fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF7C8DA6)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RightOfReplyPortal(
                              currentUser: widget.currentUser),
                        ),
                      );
                    },
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    tileColor: Colors.white.withValues(alpha: 0.03),
                  ),
                  if (widget.currentUser.role == UserRole.party)
                    const SizedBox(height: 8),
                ],
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.crimson.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout_rounded,
                        color: AppTheme.crimson, size: 20),
                  ),
                  title: Text('Sign Out',
                      style: GoogleFonts.inter(
                          color: AppTheme.crimson,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onLogout();
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  tileColor: Colors.white.withValues(alpha: 0.03),
                ),
                const SizedBox(height: 16),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Role-aware tabs (#4/#6) ──────────────────────
  bool get _isPartyAccount => widget.currentUser.role == UserRole.party;

  void _openParty(String partyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartyProfileScreen(
          partyId: partyId,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  List<Widget> get _tabViews {
    final user = widget.currentUser;
    if (_isPartyAccount) {
      // Party accounts: own party activity + specialized functions screen (#6).
      return [
        _PartyActivityTab(currentUser: user),
        PartyFunctionsScreen(currentUser: user),
      ];
    }
    final views = <Widget>[
      _FeedTab(
        isBroadChannel: _feedSubTab == 1,
        posts: _filteredPosts,
        currentUser: user,
        onPartyTap: _openParty,
        onRefresh: _loadFeedPosts,
      ),
    ];
    // Party members get a dedicated Party view (#4).
    if (user.role == UserRole.partyMember) {
      views.add(_PartyActivityTab(currentUser: user));
    }
    views.addAll([
      _ExploreTab(currentUser: user),
      _NotificationsTab(),
      _ProfileTab(user: user),
    ]);
    return views;
  }

  Widget _buildBody() {
    return Stack(
      children: [
        IndexedStack(
          index: _currentTab,
          children: _tabViews,
        ),
        // ── Loading overlay ───────────────────────────
        if (_isLoadingFeed)
          Container(
            color: AppTheme.deepNavy.withValues(alpha: 0.5),
            child: const Center(
              child: CircularProgressIndicator(
                color: AppTheme.saffron,
              ),
            ),
          ),

        // ── Greeting overlay ──────────────────────────
        // Kept permanently mounted so its animation controllers are never
        // disposed mid-flight; visibility is driven by opacity instead.
        Positioned(
          top: 24,
          left: 20,
          right: 20,
          child: IgnorePointer(
            ignoring: !_showGreeting,
            child: AnimatedOpacity(
              opacity: _showGreeting ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.saffron.withValues(alpha: 0.85),
                            const Color(0xFFFF9E40).withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Text('👋', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_greeting, $_firstName!',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Welcome to Polyticks – your political feed is ready.',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navyLight.withValues(alpha: 0.8),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            currentIndex: _currentTab,
            onTap: (i) => setState(() => _currentTab = i),
            selectedItemColor: AppTheme.saffron,
            unselectedItemColor: const Color(0xFF64748B),
            // Icon-only nav: labels are required by BottomNavigationBar's
            // assertion, so use empty strings and hide them entirely.
            showSelectedLabels: false,
            showUnselectedLabels: false,
            selectedFontSize: 0,
            unselectedFontSize: 0,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: _navItems,
          ),
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> get _navItems {
    if (_isPartyAccount) {
      // Party accounts: Party activity + Functions only (#6).
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_outlined),
          activeIcon: Icon(Icons.account_balance_rounded),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.handyman_outlined),
          activeIcon: Icon(Icons.handyman_rounded),
          label: '',
        ),
      ];
    }
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home_rounded),
        label: '',
      ),
    ];
    if (widget.currentUser.role == UserRole.partyMember) {
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.account_balance_outlined),
        activeIcon: Icon(Icons.account_balance_rounded),
        label: '',
      ));
    }
    items.addAll(const [
      BottomNavigationBarItem(
        icon: Icon(Icons.explore_outlined),
        activeIcon: Icon(Icons.explore_rounded),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.notifications_outlined),
        activeIcon: Icon(Icons.notifications_rounded),
        label: '',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline_rounded),
        activeIcon: Icon(Icons.person_rounded),
        label: '',
      ),
    ]);
    return items;
  }
}

// ─────────────────────────────────────────────
//  Party Activity Tab (#4) – activity only from
//  the user's party and its members.
// ─────────────────────────────────────────────
class _PartyActivityTab extends StatelessWidget {
  final AppUser currentUser;
  const _PartyActivityTab({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final partyId = currentUser.partyId;
    final memberIds = mockAccounts
        .map((a) => a['user'] as AppUser)
        .where((u) => u.role == UserRole.partyMember && u.partyId == partyId)
        .map((u) => u.id)
        .toSet();
    final posts = mockPosts
        .where((p) =>
            p.partyId == partyId ||
            (p.authorId != null && memberIds.contains(p.authorId)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return RefreshIndicator(
      color: AppTheme.saffron,
      backgroundColor: AppTheme.navyCard,
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          Text('Your Party',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text('Official updates and member activity',
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF7C8DA6))),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('No party activity yet.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF7C8DA6))),
              ),
            )
          else
            ...posts.map((p) => PostCard(key: ValueKey(p.id), post: p, currentUser: currentUser)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Feed Tab
// ─────────────────────────────────────────────
class _FeedTab extends StatelessWidget {
  final List<Post> posts;
  final AppUser currentUser;
  final void Function(String partyId) onPartyTap;
  final Future<void> Function() onRefresh;

  String timeAgo(String dateStr) {
    try {
      final diff = DateTime.now().difference(DateTime.parse(dateStr)).inSeconds;
      if (diff < 60) return 'Just now';
      if (diff < 3600) return '${(diff / 60).floor()}m ago';
      if (diff < 86400) return '${(diff / 3600).floor()}h ago';
      return '${(diff / 86400).floor()}d ago';
    } catch (_) {
      return dateStr;
    }
  }

  final bool isBroadChannel;

  const _FeedTab({
    required this.isBroadChannel,
    required this.posts,
    required this.currentUser,
    required this.onPartyTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.saffron,
      backgroundColor: AppTheme.navyCard,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          // ── Stories bar (party avatars) ───────────────

          if (!isBroadChannel) ...[
          // ── Community Selector Banner (hidden in broad view, #3) ──
          GestureDetector(
            onTap: () {
              showCommunitySelectorDialog(
                context,
                currentUser: currentUser,
                onCommunitySelected: (_) => onRefresh(),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.navyCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.saffron.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.saffron.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.roofing_rounded,
                      color: AppTheme.saffron,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser.communityId != null
                              ? currentUser.communityId!
                              : 'Select Your Community / Ward',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentUser.communityId != null
                              ? 'Tap to switch ward or request new community'
                              : 'Tap to connect to hyper-local feeds & polls',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF90A4AE),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.unfold_more_rounded,
                    color: AppTheme.saffron,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          ],
          const SizedBox(height: 16),

          // ── Feed label ────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Your Feed',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          // ── Posts ─────────────────────────────────────
          ...posts.map((post) {
            return PostCard(
              post: post,
              currentUser: currentUser,
              onPartyTap: () => onPartyTap(post.partyId),
            );
          }),
        ],
      ).animate().fadeIn(duration: 350.ms),
    );
  }
}

// ─────────────────────────────────────────────
//  Party Stories Bar
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
//  Explore Tab
// ─────────────────────────────────────────────
class _ExploreTab extends StatefulWidget {
  final AppUser currentUser;
  const _ExploreTab({required this.currentUser});

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.saffron,
          labelColor: AppTheme.saffron,
          unselectedLabelColor: const Color(0xFF7C8DA6),
          labelStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Following'), Tab(text: 'Discover')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFollowing(),
              _buildDiscover(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Following: parties + members the user follows (#2) ──
  Widget _buildFollowing() {
    final followedParties = mockParties
        .where((p) =>
            (mockFollowers[p.id] ?? []).contains(widget.currentUser.id))
        .toList();
    final followedMembers = mockAccounts
        .map((a) => a['user'] as AppUser)
        .where((u) =>
            u.role == UserRole.partyMember &&
            isFollowingMember(u.id, widget.currentUser.id))
        .toList();

    if (followedParties.isEmpty && followedMembers.isEmpty) {
      return Center(
        child: Text(
          'You are not following any parties or members yet.\nFind them in the Discover tab.',
          textAlign: TextAlign.center,
          style:
              GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7C8DA6)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...followedParties.map(_partyTile),
        ...followedMembers.map(_memberTile),
      ],
    );
  }

  Widget _partyTile(Party party) {
    final followers = mockFollowers[party.id]?.length ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.navyLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
              child:
                  Text(party.logoEmoji, style: const TextStyle(fontSize: 24))),
        ),
        title: Text(party.name,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white)),
        subtitle: Text(
          '${_formatNum(followers)} followers · ${_formatNum(party.memberCount)} members',
          style: GoogleFonts.inter(
              fontSize: 12, color: const Color(0xFF64748B)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: Color(0xFF64748B)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PartyProfileScreen(
              partyId: party.id,
              currentUser: widget.currentUser,
            ),
          ),
        ),
      ),
    );
  }

  Widget _memberTile(AppUser member) {
    final party = partyById(member.partyId!);
    final followers = mockMemberFollowers[member.id]?.length ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: UserAvatar(user: member, radius: 22),
        title: Text(member.displayName,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white)),
        subtitle: Text(
          '${member.partyRole?.label ?? 'Party Member'}'
          '${party != null ? ' · ${party.shortName}' : ''} · $followers followers',
          style: GoogleFonts.inter(
              fontSize: 12, color: const Color(0xFF64748B)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: Color(0xFF64748B)),
        onTap: () => party != null
            ? Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PartyProfileScreen(
                    partyId: party.id,
                    currentUser: widget.currentUser,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // ── Discover: relevant posts from sources not followed ──
  Widget _buildDiscover() {
    final followedPartyIds = mockParties
        .where((p) =>
            (mockFollowers[p.id] ?? []).contains(widget.currentUser.id))
        .map((p) => p.id)
        .toSet();
    double relevance(Post p) {
      final engagement = (p.likeCount - p.dislikeCount).clamp(0, 1 << 30);
      final hours = DateTime.now().difference(p.createdAt).inHours.clamp(1, 9999);
      return engagement / hours;
    }

    final posts = mockPosts
        .where((p) => !followedPartyIds.contains(p.partyId) && !p.isHidden)
        .toList()
      ..sort((a, b) => relevance(b).compareTo(relevance(a)));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text('Relevant to you',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7C8DA6))),
        ),
        ...posts.map((p) => PostCard(
              key: ValueKey(p.id),
              post: p,
              currentUser: widget.currentUser,
            )),
      ],
    );
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}
class _NotificationsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('🗳️', 'Aam Aadmi Dal posted a new update', '2m ago'),
      ('💬', 'Your comment received a reply', '15m ago'),
      ('👍', 'Bharatiya Rashtriya Morcha liked your activity', '1h ago'),
      ('📊', 'New poll from Janshakti Party', '3h ago'),
      ('🔔', 'Aam Aadmi Dal launched Jan Suraksha Yojana', '5h ago'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Notifications',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 16),
        ...items.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Text(item.$1, style: const TextStyle(fontSize: 24)),
                title: Text(item.$2,
                    style:
                        GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                subtitle: Text(item.$3,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: const Color(0xFF64748B))),
              ),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Verification status chip + navigation helper
// ─────────────────────────────────────────────
(String, Color, IconData) _verificationVisual(AppUser user) {
  switch (user.verificationStatus) {
    case 'approved':
      return ('Verified', AppTheme.emerald, Icons.verified_rounded);
    case 'pending':
      return ('Under review', AppTheme.gold, Icons.hourglass_top_rounded);
    case 'rejected':
      return ('Rejected — re-apply', AppTheme.crimson, Icons.gpp_bad_rounded);
    default:
      return ('Not verified', const Color(0xFF7C8DA6), Icons.gpp_maybe_rounded);
  }
}

void _openVerificationStatus(BuildContext context, AppUser currentUser) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VerificationStatusScreen(
        currentUser: currentUser,
        onChanged: () {},
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  Profile Tab
// ─────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  final AppUser user;
  const _ProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final followedParties = mockParties
        .where((p) =>
            (mockFollowers[p.id] ?? []).contains(user.id) ||
            user.partyId == p.id)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Profile header ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.navyCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E3054), width: 1),
          ),
          child: Column(
            children: [
              UserAvatar(user: user, radius: 40),
              const SizedBox(height: 12),
              Text(user.displayName,
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 6),
              RoleBadge(role: user.role),
              const SizedBox(height: 10),
              // Account verification status — tap to view/re-apply.
              GestureDetector(
                onTap: () => _openVerificationStatus(context, user),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.navyCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF27354F)),
                  ),
                  child: Builder(builder: (context) {
                    final (label, color, icon) = _verificationVisual(user);
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text('Account: $label',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          size: 14, color: Color(0xFF64748B)),
                    ]);
                  }),
                ),
              ),
              if (user.role == UserRole.partyMember && user.partyId != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Member of ${partyById(user.partyId!)?.name ?? ''}'
                  '${user.partyRole != null ? ' · ${user.partyRole!.label}' : ''}',
                  style: GoogleFonts.inter(
                      color: AppTheme.memberColor, fontSize: 13),
                ),
                // Membership management lives on the party page (Members tab
                // header panel) — no leave action here by design.
                Text('Open your party page to manage membership.',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF7C8DA6), fontSize: 11)),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StatChip(                      label: 'Following',
                      value: followedParties.length.toString(),
                      icon: Icons.people_alt_outlined),
                  StatChip(                      label: 'Comments',
                      value: mockComments
                          .where((c) => c.authorId == user.id)
                          .length
                          .toString(),
                      icon: Icons.chat_bubble_outline_rounded),
                  const StatChip(                      label: 'Since',
                      value: 'Aug \'26',
                      icon: Icons.calendar_today_outlined),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Text('About',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              user.role == UserRole.janta
                  ? 'You are a Janta user. You can follow parties, view all content and comment on party posts.'
                  : user.role == UserRole.party
                      ? 'You represent a registered political party. You can create public posts and run exclusive member polls.'
                      : 'You are a Party Member. You can react to and comment on posts from any party, and access your own party\'s exclusive polls.',
              style: GoogleFonts.inter(
                  color: const Color(0xFF90A4AE), fontSize: 13, height: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}
