// ─────────────────────────────────────────────
//  Polyticks V4.0 – Subscription Service (B2B Monetization)
// ─────────────────────────────────────────────
//
//  Client-side contract for the paid-org flow ($10–$50/mo tiers).
//  Mirrors the server state machine:
//
//    startUpgrade(tier)      → edge fn create-subscription-checkout
//    (mock: trialing row created directly; real: Razorpay checkout)
//    fetchActiveTier(orgId)  → mirrors public.active_org_tier()
//                              NULL unless status ∈ {trialing, active}
//                              and current_period_end > now
//    cancel()                → edge fn cancel-subscription
//
//  SIMULATION MODE keeps an in-memory store so tests exercise identical
//  transitions without a backend (same pattern as DigiLockerVerification-
//  Service / FactCheckService — see docs/V2_STATE_MANAGEMENT_SPEC.md §4).
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../core/exceptions.dart';
import 'supabase_service.dart';

enum OrgTier { basic, gold, platinum }

OrgTier orgTierFromString(String? value) {
  switch (value) {
    case 'gold':
      return OrgTier.gold;
    case 'platinum':
      return OrgTier.platinum;
    default:
      return OrgTier.basic;
  }
}

class CheckoutResult {
  final String checkoutId;
  final OrgTier tier;
  final bool mock;
  final DateTime? trialEndsAt;
  const CheckoutResult({
    required this.checkoutId,
    required this.tier,
    required this.mock,
    this.trialEndsAt,
  });
}

class SubscriptionService {
  SubscriptionService._();

  // In-memory simulation store (orgId → subscription record).
  static final Map<String, Map<String, dynamic>> _simulated = {};

  static const Duration trialPeriod = Duration(days: 14);

  /// True when the upgrade UI may be offered (checkout configured or
  /// simulation mode). Live payments stay OFF until the Pro update.
  static bool get isUpgradeAvailable =>
      AppConfig.isPaymentsConfigured ||
      SupabaseService.instance.isRealSupabase ||
      !kIsWeb; // simulation on any native target

  // ── START UPGRADE ───────────────────────────────────────────────────────

  static Future<CheckoutResult> startUpgrade(OrgTier tier) async {
    if (tier == OrgTier.basic) {
      throw const SubscriptionException(
        message: 'Cannot upgrade to the free basic tier.',
        userFriendlyMessage: 'Basic is the free tier — pick Gold or Platinum.',
        code: 'SUB_INVALID_TIER',
      );
    }
    final service = SupabaseService.instance;

    if (!service.isRealSupabase) {
      // Simulation: activate a trialing row directly (mirrors mock mode).
      final trialEnd =
          DateTime.now().toUtc().add(trialPeriod);
      _simulated[service.currentUserId ?? 'sim-org'] = {
        'tier': tier.name,
        'status': 'trialing',
        'provider_ref': 'mock-sub-${DateTime.now().microsecondsSinceEpoch}',
        'trial_ends_at': trialEnd.toIso8601String(),
        'current_period_end': trialEnd.toIso8601String(),
        'canceled_at': null,
      };
      debugPrint('Subscription SIMULATION: trialing ${tier.name} started');
      return CheckoutResult(
        checkoutId: _simulated[service.currentUserId ?? 'sim-org']!['provider_ref']
            as String,
        tier: tier,
        mock: true,
        trialEndsAt: trialEnd,
      );
    }

    try {
      final response = await service.client!.functions.invoke(
        'create-subscription-checkout',
        method: HttpMethod.post,
        body: {'tier': tier.name},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw SubscriptionException(
          message: '${data['error']}',
          userFriendlyMessage:
              data['error'] == 'Org already has an active subscription'
                  ? 'Your organization already has an active subscription.'
                  : 'Could not start the upgrade. Please try again.',
          code: 'SUB_CHECKOUT_FAILED',
        );
      }
      return CheckoutResult(
        checkoutId: data['checkoutId'] as String,
        tier: tier,
        mock: data['mock'] == true,
        trialEndsAt: data['trialEndsAt'] != null
            ? DateTime.parse(data['trialEndsAt'] as String)
            : null,
      );
    } on PolyticksDomainException {
      rethrow;
    } catch (e) {
      throw SubscriptionException(
        message: 'checkout invoke failed: $e',
        userFriendlyMessage: 'Could not start the upgrade. Please try again.',
        code: 'SUB_CHECKOUT_FAILED',
      );
    }
  }

  // ── ACTIVE TIER (mirrors public.active_org_tier()) ──────────────────────

  static Future<OrgTier> fetchActiveTier(String orgId) async {
    final service = SupabaseService.instance;
    if (!service.isRealSupabase) {
      final row = _simulated[orgId];
      return _liveTierFromRow(row);
    }
    // Live mode: mock ids ('p1', 'p_u1'…) aren't UUIDs — fall back to the
    // authenticated user, else there is nothing to look up.
    if (!SupabaseService.isUuid(orgId)) orgId = service.currentUserId ?? '';
    if (!SupabaseService.isUuid(orgId)) return OrgTier.basic;
    try {
      final rows = await service.client!
          .from('subscriptions')
          .select('tier, status, current_period_end')
          .eq('org_id', orgId)
          .limit(1);
      if (rows.isEmpty) return OrgTier.basic;
      return _liveTierFromRow(rows.first);
    } catch (e) {
      debugPrint('fetchActiveTier failed: $e');
      return OrgTier.basic;
    }
  }

  static OrgTier _liveTierFromRow(Map<String, dynamic>? row) {
    if (row == null) return OrgTier.basic;
    final status = row['status'];
    if (status != 'trialing' && status != 'active') return OrgTier.basic;
    final periodEnd = row['current_period_end'];
    if (periodEnd != null &&
        DateTime.parse(periodEnd as String).isBefore(DateTime.now())) {
      return OrgTier.basic;
    }
    return orgTierFromString(row['tier'] as String?);
  }

  // ── STATUS (B15: past-due / renewal awareness) ──────────────────────────

  /// Raw subscription status for an org
  /// ('trialing'|'active'|'past_due'|'canceled'|'expired'), or null.
  static Future<String?> fetchStatus(String orgId) async {
    final service = SupabaseService.instance;
    if (!service.isRealSupabase) {
      return _simulated[orgId]?['status'] as String?;
    }
    if (!SupabaseService.isUuid(orgId)) orgId = service.currentUserId ?? '';
    if (!SupabaseService.isUuid(orgId)) return null;
    try {
      final rows = await service.client!
          .from('subscriptions')
          .select('status')
          .eq('org_id', orgId)
          .limit(1);
      if (rows.isEmpty) return null;
      return rows.first['status'] as String?;
    } catch (e) {
      debugPrint('fetchStatus failed: $e');
      return null;
    }
  }

  // ── CANCEL ──────────────────────────────────────────────────────────────

  static Future<void> cancel() async {
    final service = SupabaseService.instance;
    if (!service.isRealSupabase) {
      final key = service.currentUserId ?? 'sim-org';
      final row = _simulated[key];
      if (row == null) {
        throw const SubscriptionException(
          message: 'No simulated subscription to cancel.',
          userFriendlyMessage: 'No active subscription found.',
          code: 'SUB_NOT_FOUND',
        );
      }
      row['status'] = 'canceled';
      row['canceled_at'] = DateTime.now().toUtc().toIso8601String();
      debugPrint('Subscription SIMULATION: canceled');
      return;
    }

    try {
      final response = await service.client!.functions.invoke(
        'cancel-subscription',
        method: HttpMethod.post,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw SubscriptionException(
          message: '${data['error']}',
          userFriendlyMessage: 'Cancellation failed. Please try again.',
          code: 'SUB_CANCEL_FAILED',
        );
      }
    } on PolyticksDomainException {
      rethrow;
    } catch (e) {
      throw SubscriptionException(
        message: 'cancel invoke failed: $e',
        userFriendlyMessage: 'Cancellation failed. Please try again.',
        code: 'SUB_CANCEL_FAILED',
      );
    }
  }

  /// True when priority push broadcasts are unlocked for [tier] — requires
  /// a paid tier AND the pro-tier flag (placeholder until v4.1).
  static bool get priorityBroadcastUnlocked =>
      AppConfig.priorityBroadcastEnabled;

  /// Test hook: reset simulation state between tests.
  @visibleForTesting
  static void resetSimulation() => _simulated.clear();
}
