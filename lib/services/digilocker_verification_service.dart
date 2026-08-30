// ─────────────────────────────────────────────
//  Polyticks V4.0 – DigiLocker Verification Service
// ─────────────────────────────────────────────
//
//  Automated ID verification via DigiLocker / Govt e-ID, replacing the
//  manual document-upload bottleneck on mobile (manual upload remains the
//  web-only fallback — see IDVerificationService).
//
//  Flow:
//    1. startVerification()      → edge fn `digilocker-initiate`
//       Returns {requestId, consentUrl}. Client opens consentUrl.
//    2. User consents on DigiLocker; provider redirects back to the app
//       with an authorization code.
//    3. finalizeVerification()   → edge fn `digilocker-finalize`
//       Server verifies ownership/state, marks verified/failed and flips
//       profiles.is_verified via service_role.
//
//  SIMULATION MODE mirrors these semantics in-memory so tests and offline
//  dev runs exercise identical transitions (same contract as other v4/v2
//  services — see docs/V2_STATE_MANAGEMENT_SPEC.md § Testing contract).
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../core/exceptions.dart';
import 'supabase_service.dart';

class DigiLockerRequest {
  final String requestId;
  final String consentUrl;
  final bool mock;
  const DigiLockerRequest({
    required this.requestId,
    required this.consentUrl,
    required this.mock,
  });
}

class DigiLockerResult {
  final bool verified;
  final String status; // 'verified' | 'failed' | terminal row status
  final String? failureReason;
  const DigiLockerResult({
    required this.verified,
    required this.status,
    this.failureReason,
  });
}

class DigiLockerVerificationService {
  DigiLockerVerificationService._();

  // In-memory simulation state (keyed by requestId).
  static final Map<String, String> _simulatedRequests = {};

  /// True when automated verification can be offered on this platform.
  /// Available across web and mobile targets.
  static bool get isAvailable => AppConfig.isDigilockerEnabled;

  /// Starts a verification flow. Returns the request id + consent URL to open.
  static Future<DigiLockerRequest> startVerification() async {
    if (!AppConfig.isDigilockerEnabled) {
      throw const DigiLockerFlowException(
        message: 'DigiLocker flow disabled by AppConfig.',
        userFriendlyMessage:
            'Instant verification is not available yet. Please use manual ID upload.',
        code: 'DIGILOCKER_DISABLED',
      );
    }

    final service = SupabaseService.instance;
    if (!service.isRealSupabase) {
      // Simulation: synthesize a mock request.
      final requestId =
          'sim-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      _simulatedRequests[requestId] = 'initiated';
      debugPrint('DigiLocker SIMULATION: started request $requestId');
      return DigiLockerRequest(
        requestId: requestId,
        consentUrl: 'https://mock-digilocker.polyticks.local/consent',
        mock: true,
      );
    }

    try {
      final response = await service.client!.functions.invoke(
        'digilocker-initiate',
        method: HttpMethod.post,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw DigiLockerFlowException(message: '${data['error']}');
      }
      _simulatedRequests[data['requestId'] as String] = 'initiated';
      return DigiLockerRequest(
        requestId: data['requestId'] as String,
        consentUrl: data['consentUrl'] as String,
        mock: data['mock'] == true,
      );
    } on DigiLockerFlowException {
      rethrow;
    } catch (e) {
      throw DigiLockerFlowException(message: 'initiate failed: $e');
    }
  }

  /// Completes the flow after the provider redirect. [code] comes from the
  /// DigiLocker callback; ignored in simulation/mock mode.
  static Future<DigiLockerResult> finalizeVerification({
    required String requestId,
    String? code,
  }) async {
    final service = SupabaseService.instance;

    if (!service.isRealSupabase) {
      // Simulation: mirror server semantics (auto-verify).
      if (!_simulatedRequests.containsKey(requestId)) {
        throw const DigiLockerFlowException(
            message: 'Unknown simulated requestId.');
      }
      _simulatedRequests[requestId] = 'verified';
      debugPrint('DigiLocker SIMULATION: verified $requestId');
      return const DigiLockerResult(verified: true, status: 'verified');
    }

    try {
      final response = await service.client!.functions.invoke(
        'digilocker-finalize',
        method: HttpMethod.post,
        body: {'requestId': requestId, 'code': code},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw DigiLockerFlowException(message: '${data['error']}');
      }
      final status = data['status'] as String? ?? 'failed';
      _simulatedRequests[requestId] = status;
      return DigiLockerResult(
        verified: status == 'verified',
        status: status,
        failureReason: null,
      );
    } on DigiLockerFlowException {
      rethrow;
    } catch (e) {
      throw DigiLockerFlowException(message: 'finalize failed: $e');
    }
  }

  /// Latest verification request status for the current user
  /// ('initiated'|'otp_sent'|'docs_fetched'|'verified'|'failed'), or null.
  static Future<String?> fetchLatestStatus(String userId) async {
    final service = SupabaseService.instance;
    if (!service.isRealSupabase) {
      if (_simulatedRequests.isEmpty) return null;
      return _simulatedRequests.values.last;
    }
    try {
      final rows = await service.client!
          .from('verification_requests')
          .select('status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return rows.first['status'] as String?;
    } catch (e) {
      debugPrint('fetchLatestStatus failed: $e');
      return null;
    }
  }

  /// Test hook: reset simulation state between tests.
  @visibleForTesting
  static void resetSimulation() => _simulatedRequests.clear();
}
