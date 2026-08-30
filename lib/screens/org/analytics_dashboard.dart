// ─────────────────────────────────────────────
//  Polyticks V4.0 – B2B Analytics Dashboard (org-scoped)
// ─────────────────────────────────────────────
//
//  Campaign analytics for paid orgs: engagement totals, crowd-trust score,
//  fact-check outcome breakdown. Data comes from org_analytics_summary
//  (migration 09) via AnalyticsService; access is RLS-enforced server-side.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/analytics_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_theme.dart';

class OrgAnalyticsDashboard extends StatefulWidget {
  final AppUser currentUser;
  const OrgAnalyticsDashboard({super.key, required this.currentUser});

  @override
  State<OrgAnalyticsDashboard> createState() => _OrgAnalyticsDashboardState();
}

class _OrgAnalyticsDashboardState extends State<OrgAnalyticsDashboard> {
  OrgAnalyticsSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await AnalyticsService.fetchSummary(widget.currentUser.id);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        foregroundColor: Colors.white,
        title: Text('Campaign Analytics',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.saffron))
          : RefreshIndicator(
              color: AppTheme.saffron,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_summary == null) ...[
                    _emptyState(),
                  ] else ...[
                    _trustCard(),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _statCard('Posts', '${_summary!.totalPosts}',
                          sub: '${_summary!.postsLast30d} in last 30d')),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Likes', '${_summary!.totalLikes}',
                          icon: Icons.thumb_up_alt_rounded,
                          iconColor: Colors.greenAccent)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _statCard('Dislikes',
                          '${_summary!.totalDislikes}',
                          sub: '${_summary!.dislikeRatioPct}% dislike ratio',
                          icon: Icons.thumb_down_alt_rounded,
                          iconColor: AppTheme.crimson)),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('Community Notes',
                          '${_summary!.communityNotesReceived}')),
                    ]),
                    const SizedBox(height: 18),
                    _outcomesCard(),
                  ],
                ],
              ),
            ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _emptyState() => Column(children: [
        const SizedBox(height: 80),
        const Icon(Icons.query_stats_rounded,
            color: Color(0xFF7C8DA6), size: 56),
        const SizedBox(height: 14),
        Text('No analytics yet',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 17)),
        const SizedBox(height: 6),
        Text(
          'Stats appear here once your organization publishes posts.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Color(0xFF7C8DA6), fontSize: 13),
        ),
      ]);

  Widget _trustCard() {
    final score = _summary?.trustScorePct ?? 100.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.saffron.withValues(alpha: 0.15),
          AppTheme.navyLight,
        ]),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppTheme.saffron.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Crowd Trust Score',
              style: GoogleFonts.inter(
                  color: Color(0xFF90A4AE), fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(score.toStringAsFixed(0),
                style: GoogleFonts.inter(
                    color: AppTheme.saffron,
                    fontSize: 42,
                    fontWeight: FontWeight.w800)),
            Padding(
              padding: EdgeInsets.only(bottom: 8, left: 4),
              child: Text('%',
                  style: GoogleFonts.inter(
                      color: AppTheme.saffron, fontSize: 18)),
            ),
            const Spacer(),
            FutureBuilder<OrgTier>(
              future:
                  SubscriptionService.fetchActiveTier(widget.currentUser.id),
              builder: (_, snap) => Text(
                (snap.data ?? OrgTier.basic) == OrgTier.basic
                    ? 'FREE VIEW'
                    : '${snap.data!.name.toUpperCase()} MEMBER',
                style: GoogleFonts.inter(
                    color: Color(0xFF90A4AE), fontSize: 11, letterSpacing: 1),
              ),
            ),
          ]),
          Text(
            'Share of judged posts that ended clean or with accepted community context.',
            style: GoogleFonts.inter(
                color: Color(0xFF7C8DA6), fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value,
      {String? sub, IconData? icon, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.navyLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF243450)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? AppTheme.saffron, size: 15),
              const SizedBox(width: 5),
            ],
            Text(label.toUpperCase(),
                style: GoogleFonts.inter(
                    color: const Color(0xFF7C8DA6),
                    fontSize: 10,
                    letterSpacing: 1)),
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          if (sub != null)
            Text(sub,
                style: GoogleFonts.inter(
                    color: const Color(0xFF7C8DA6), fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _outcomesCard() {
    final s = _summary!;
    final rows = [
      ('Clean', s.cleanPosts, Colors.greenAccent),
      ('Context accepted', s.contextAccepted, AppTheme.saffron),
      ('Under review', s.underReview, Colors.orangeAccent),
      ('Disputed', s.disputed, AppTheme.crimson),
      ('Auto-hidden', s.autoHidden, AppTheme.crimson),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF243450)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FACT-CHECK OUTCOMES ON YOUR CONTENT',
              style: GoogleFonts.inter(
                  color: const Color(0xFF7C8DA6),
                  fontSize: 10.5,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: r.$2 > 0 ? r.$3 : const Color(0xFF37474F),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.$1,
                        style: GoogleFonts.inter(
                            color: const Color(0xFFB0BEC5), fontSize: 13)),
                  ),
                  Text('${r.$2}',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
              )),
        ],
      ),
    );
  }
}
