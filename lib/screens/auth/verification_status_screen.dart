// ─────────────────────────────────────────────
//  Polyticks – Account Verification Status Screen
//
//  Single place to see your ID-verification state and re-apply after a
//  rejection. Reached from the profile screen and from every verification
//  warning prompt in the app.
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'id_verification_screen.dart';

class VerificationStatusScreen extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onChanged; // notify parent to refresh local state

  const VerificationStatusScreen({
    super.key,
    required this.currentUser,
    required this.onChanged,
  });

  @override
  State<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  bool _loading = true;
  late String? _status = widget.currentUser.verificationStatus;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final fresh =
        await SupabaseService.instance.getMyVerificationStatus();
    if (!mounted) return;
    setState(() {
      if (fresh != null) {
        _status = fresh;
        widget.currentUser.verificationStatus = fresh;
      }
      _loading = false;
    });
    widget.onChanged();
  }

  /// Opens the full document-upload flow (works in both live and simulation
  /// mode). On return the status is re-fetched so a fresh submission shows
  /// as 'pending' immediately.
  Future<void> _startOrReapplyVerification() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IdVerificationScreen(
          currentUser: widget.currentUser,
          onContinue: () => Navigator.pop(context),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _status = 'pending');
    widget.onChanged();
    await _refresh();
  }

  Future<void> _unlinkAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        title: Text('Unlink Account?',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
            'This permanently deletes your profile, posts and interactions. This action cannot be undone.',
            style: GoogleFonts.inter(color: const Color(0xFF90A4AE), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No, go back',
                style: GoogleFonts.inter(color: const Color(0xFF90A4AE))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
            child: Text('Yes, I\'m sure',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    final success = await SupabaseService.instance.deleteMyAccount();
    if (!mounted) return;
    if (success) {
      widget.onChanged();
      Navigator.of(context).pop('unlinked');
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error unlinking account. Please try again.'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParty = widget.currentUser.role == UserRole.party;
    final isApproved = _status == 'approved';

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        title: Text('Account Verification',
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.saffron))
          : RefreshIndicator(
              color: AppTheme.saffron,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _statusCard(),
                  const SizedBox(height: 16),
                  if (isParty) ...[
                    _organizationCard(),
                  ] else if (isApproved) ...[
                    _approvedVerifiedCard(),
                  ] else ...[
                    _timelineCard(),
                    if (_status == 'rejected') _reapplyCard(),
                    if (_status == null || _status == 'unverified') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startOrReapplyVerification,
                          icon: const Icon(Icons.badge_rounded),
                          label: Text('Verify My Account',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.saffron,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ).animate().fadeIn(duration: 300.ms),
            ),
    );
  }

  Widget _organizationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF27354F)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.saffron.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.saffron.withValues(alpha: 0.5), width: 2),
            ),
            child: const Icon(Icons.business_rounded, color: AppTheme.saffron, size: 36),
          ),
          const SizedBox(height: 14),
          Text('Organization',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Pre-authorized offline',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: const Color(0xFF90A4AE), fontSize: 13, height: 1.6)),
        ],
      ),
    );
  }

  Widget _approvedVerifiedCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF27354F)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.5), width: 2),
            ),
            child: const Icon(Icons.verified_user_rounded, color: AppTheme.emerald, size: 36),
          ),
          const SizedBox(height: 14),
          Text('KYC Verified ✓',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startOrReapplyVerification,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Redo KYC',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.saffron,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _unlinkAccount,
              icon: const Icon(Icons.delete_forever_rounded),
              label: Text('Unlink Account',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.crimson,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }


  ({Color color, IconData icon, String title, String body}) get _state {
    switch (_status) {
      case 'approved':
        return (
          color: AppTheme.emerald,
          icon: Icons.verified_rounded,
          title: 'Verified Account',
          body: 'Your identity is confirmed. You can add Community Notes, '
              'vote on fact checks and participate fully.'
        );
      case 'pending':
        return (
          color: AppTheme.gold,
          icon: Icons.hourglass_top_rounded,
          title: 'Under Review',
          body: 'Your documents are with our moderation team. Reviews '
              'typically complete within 24 hours. Pull down to refresh.'
        );
      case 'rejected':
        return (
          color: AppTheme.crimson,
          icon: Icons.gpp_bad_rounded,
          title: 'Verification Rejected',
          body: 'We could not verify your identity from the document '
              'provided. Common reasons: blurry image, cropped edges, or '
              'details not matching your account. Your document has been '
              'permanently deleted — you can safely re-apply below.'
        );
      default:
        return (
          color: const Color(0xFF7C8DA6),
          icon: Icons.gpp_maybe_rounded,
          title: 'Not Verified',
          body: 'Verify your account to unlock Community Notes, fact-check '
              'voting and full civic participation. Your document is stored '
              'privately and deleted right after review.'
        );
    }
  }

  Widget _statusCard() {
    final s = _state;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: s.color.withValues(alpha: 0.5), width: 2),
            ),
            child: Icon(s.icon, color: s.color, size: 36),
          ),
          const SizedBox(height: 14),
          Text(s.title,
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text(s.body,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: const Color(0xFF90A4AE), fontSize: 13, height: 1.6)),
        ],
      ),
    );
  }

  Widget _timelineCard() {
    Widget step(String label, bool done, {bool failed = false}) {
      final c = failed ? AppTheme.crimson : (done ? AppTheme.emerald : const Color(0xFF44546C));
      return Row(children: [
        Icon(failed ? Icons.close_rounded : (done ? Icons.check_circle_rounded : Icons.radio_button_unchecked),
            size: 18, color: c),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                color: done || failed ? Colors.white : const Color(0xFF64748B))),
      ]);
    }

    final st = _status ?? 'unverified';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27354F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progress',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF7C8DA6))),
          const SizedBox(height: 12),
          step('Submit ID document', st != 'unverified',
              failed: false),
          const SizedBox(height: 8),
          step('Moderator review', st == 'approved'),
          const SizedBox(height: 8),
          step('Verified', st == 'approved', failed: st == 'rejected'),
        ],
      ),
    );
  }

  Widget _reapplyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.saffron.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.saffron.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Re-apply',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Tips for a successful re-application: use a clear photo of the '
            'full document on a flat surface, avoid glare, and make sure the '
            'name matches your account.',
            style: GoogleFonts.inter(
                color: const Color(0xFF90A4AE), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startOrReapplyVerification,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Re-submit Documents',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.saffron,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
