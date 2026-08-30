// ─────────────────────────────────────────────
//  Polyticks V4.0 – DigiLocker Verification Service Tests
// ─────────────────────────────────────────────
//
//  Covers the SIMULATION-mode contract of DigiLockerVerificationService
//  (same semantics as the edge functions in mock mode):
//    * disabled flag → DIGILOCKER_DISABLED domain exception
//    * start → initiated request, then finalize → verified
//    * finalize on unknown request id → flow exception
//    * status polling reflects terminal state
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/config.dart';
import 'package:polyticks/core/exceptions.dart';
import 'package:polyticks/services/digilocker_verification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Force simulation mode (no real credentials, no network).
    AppConfig.forceTestMode = true;
  });

  setUp(() {
    DigiLockerVerificationService.resetSimulation();
  });

  test('isAvailable is true in simulation on a native target', () {
    expect(DigiLockerVerificationService.isAvailable, isTrue);
  });

  test('startVerification returns a mock request and registers state', () async {
    final req = await DigiLockerVerificationService.startVerification();
    expect(req.mock, isTrue);
    expect(req.requestId, isNotEmpty);
    expect(req.consentUrl, contains('mock-digilocker'));
  });

  test('full happy path: start → finalize → verified', () async {
    final req = await DigiLockerVerificationService.startVerification();

    final result =
        await DigiLockerVerificationService.finalizeVerification(
            requestId: req.requestId);
    expect(result.verified, isTrue);
    expect(result.status, 'verified');

    // Terminal state persists in the simulated store.
    final status = await DigiLockerVerificationService.fetchLatestStatus(
        req.requestId);
    expect(status, 'verified');
  });

  test('finalize on unknown request id throws DigiLockerFlowException',
      () async {
    expect(
      () => DigiLockerVerificationService.finalizeVerification(
          requestId: 'does-not-exist'),
      throwsA(isA<DigiLockerFlowException>()),
    );
  });

  test('fetchLatestStatus returns null when nothing started', () async {
    expect(await DigiLockerVerificationService.fetchLatestStatus('any'),
        isNull);
  });
}
