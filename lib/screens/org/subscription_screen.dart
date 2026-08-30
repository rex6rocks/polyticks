// ─────────────────────────────────────────────
//  Polyticks V4.0 – Organization Subscription Screen
// ─────────────────────────────────────────────
//
//  Org upgrade / manage UI: Gold & Platinum tier cards, 14-day trial
//  (mock checkout until live Razorpay keys land in the v4.1 Pro update),
//  current-tier display, cancel action, priority-push status.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config.dart';
import '../../core/exceptions.dart';
import '../../models/models.dart';
import '../../services/subscription_service.dart';
import '../../services/razorpay_checkout_service.dart';
import '../../theme/app_theme.dart';

class OrgSubscriptionScreen extends StatefulWidget {
  final AppUser currentUser;
  const OrgSubscriptionScreen({super.key, required this.currentUser});

  @override
  State<OrgSubscriptionScreen> createState() => _OrgSubscriptionScreenState();
}

class _OrgSubscriptionScreenState extends State<OrgSubscriptionScreen> {
  OrgTier _currentTier = OrgTier.basic;
  String? _status; // trialing|active|past_due|canceled|expired (B15)
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orgId = widget.currentUser.id;
    final tier = await SubscriptionService.fetchActiveTier(orgId);
    final status = await SubscriptionService.fetchStatus(orgId);
    if (!mounted) return;
    setState(() {
      _currentTier = tier;
      _status = status;
    });
  }

  Future<void> _upgrade(OrgTier tier) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await SubscriptionService.startUpgrade(tier);
      if (!mounted) return;

      // B13: real mode → open the Razorpay payment sheet. Tier activation
      // still arrives via the payment-webhook, not from this result.
      if (!result.mock && AppConfig.isPaymentsConfigured) {
        final paid = await RazorpayCheckoutService.openSubscriptionSheet(
          checkoutId: result.checkoutId,
          razorpayKeyId: AppConfig.razorpayKeyId,
          orgName: widget.currentUser.displayName,
          description: 'Polyticks ${tier.name} plan',
        );
        if (!mounted) return;
        setState(() {
          _message = paid
              ? 'Payment captured — ${tier.name.toUpperCase()} activates '
                  'automatically once our webhook confirms it (moments).'
              : 'Payment not completed. Your trial/checkout is reserved — '
                  'you can retry anytime.';
        });
        return;
      }

      setState(() {
        _currentTier = tier;
        _message = result.mock
            ? '${tier.name.toUpperCase()} trial activated (simulated checkout).'
            : '${tier.name.toUpperCase()} checkout started — complete payment to activate.';
      });
    } on PolyticksDomainException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.userFriendlyMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await SubscriptionService.cancel();
      if (!mounted) return;
      setState(() {
        _currentTier = OrgTier.basic;
        _message = 'Subscription canceled. Paid features remain until period end.';
      });
    } on PolyticksDomainException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.userFriendlyMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPaidSub =
        _currentTier == OrgTier.gold || _currentTier == OrgTier.platinum;

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        foregroundColor: Colors.white,
        title: Text('Organization Plans',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // B15: payment/renewal attention banner.
            if (_status == 'past_due') ...[
              _pastDueBanner(),
              const SizedBox(height: 14),
            ],
            _currentTierCard(hasPaidSub),
            const SizedBox(height: 16),
            _tierCard(
                tier: OrgTier.gold,
                price: '₹829/mo',
                perks: const [
                  'Gold verification badge',
                  'Priority push broadcasts*',
                  'Official Right-of-Reply portal',
                  'Campaign analytics dashboard',
                ]),
            const SizedBox(height: 12),
            _tierCard(
                tier: OrgTier.platinum,
                price: '₹4,149/mo',
                perks: const [
                  'Everything in Gold',
                  'Platinum badge & top placement',
                  'Advanced constituency analytics',
                  'Early access: livestreaming (v5)',
                ]),
            if (hasPaidSub) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _busy ? null : _cancel,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.crimson,
                    side: const BorderSide(color: AppTheme.crimson)),
                child: const Text('Cancel Subscription'),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.saffron, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Text(
              '*Priority broadcasts unlock with the infrastructure upgrade '
              '(post-release update). Your tier is reserved now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: const Color(0xFF7C8DA6), fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms),
    );
  }

  /// B15: shown when the webhook records a failed renewal (past_due).
  Widget _pastDueBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.crimson.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.crimson.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: AppTheme.crimson, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Payment issue detected — your last renewal failed. '
            'Paid features are paused until the next successful charge. '
            'Update your payment method or re-subscribe below.',
            style: GoogleFonts.inter(
                color: Colors.white, fontSize: 12, height: 1.5),
          ),
        ),
      ]),
    );
  }

  Widget _currentTierCard(bool hasPaidSub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.navyLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasPaidSub ? AppTheme.saffron : const Color(0xFF243450)),
      ),
      child: Row(children: [
        Icon(hasPaidSub ? Icons.workspace_premium_rounded : Icons.account_circle_outlined,
            color: hasPaidSub ? AppTheme.saffron : const Color(0xFF7C8DA6)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            hasPaidSub
                ? 'Current plan: ${_currentTier.name.toUpperCase()}'
                : 'Current plan: Free (no active subscription)',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          ),
        ),
      ]),
    );
  }

  Widget _tierCard({
    required OrgTier tier,
    required String price,
    required List<String> perks,
  }) {
    final isCurrent = _currentTier == tier;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isCurrent ? AppTheme.saffron : const Color(0xFF243450),
            width: isCurrent ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tier.name.toUpperCase(),
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            Text(price,
                style: GoogleFonts.inter(
                    color: AppTheme.saffron,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ...perks.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.check_rounded,
                      color: AppTheme.saffron, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(p,
                        style: GoogleFonts.inter(
                            color: const Color(0xFFB0BEC5), fontSize: 12.5)),
                  ),
                ]),
              )),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed:
                (_busy || isCurrent || !SubscriptionService.isUpgradeAvailable)
                    ? null
                    : () => _upgrade(tier),
            child: Text(isCurrent
                ? 'Current Plan'
                : AppConfig.isPaymentsConfigured
                    ? 'Start 14-Day Free Trial'
                    : 'Start Trial (Simulated Checkout)'),
          ),
        ],
      ),
    );
  }
}
