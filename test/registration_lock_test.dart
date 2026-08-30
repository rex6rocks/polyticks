// ─────────────────────────────────────────────
//  Polyticks V4.0 – Registration Lock & Deep-Link Regression Guards
// ─────────────────────────────────────────────
//
//  B9 guard: migration 08's `guard_role_escalation` trigger blocks client
//  SDK writes to sensitive profile columns. These static guards pin the
//  server-side protection and the admin-path contract in place; live DB
//  verification runs via the env-bound suite after backlog B1.
//
//  B7 guard: DigiLocker callback parsing + CSRF state matching through
//  DeepLinkHandler (mock provider feeds the same production path).
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/services/deep_link_service.dart';

void main() {
  group('B9 – registration lock regression guards', () {
    final migration08 = File(
            'test/../supabase/migrations/08_v4_monetization_schema.sql')
        .readAsStringSync();

    test('migration 08 installs the role escalation guard trigger', () {
      expect(migration08, contains('guard_role_escalation'));
      expect(migration08, contains('trg_guard_role_escalation'));
      expect(migration08,
          contains('BEFORE INSERT OR UPDATE ON public.profiles'));
    });

    test('trigger blocks is_verified and privileged roles for non-admins',
        () {
      expect(migration08, contains("NEW.role IN ('admin', 'org_placeholder')"));
      expect(migration08,
          contains('NEW.is_verified IS DISTINCT FROM OLD.is_verified'));
      expect(migration08, contains('caller_is_privileged'));
    });

    test('admin approval path is allowed by caller_is_privileged', () {
      // caller_is_privileged() must accept BOTH service_role JWTs and
      // admin profiles — this is what keeps approveVerification() working
      // from the admin console (role == 'admin' JWT per main.dart routing).
      expect(migration08, contains("v_jwt_role = 'service_role'"));
      expect(migration08, contains("role = 'admin'"));
    });
  });

  group('B7 – DigiLocker deep-link handling', () {
    test('parses a valid digilocker callback URI', () {
      final cb = DigiLockerCallback.fromUri(Uri.parse(
          'polyticks://digilocker/callback?code=abc123&state=req-1'));
      expect(cb, isNotNull);
      expect(cb!.code, 'abc123');
      expect(cb.state, 'req-1');
    });

    test('rejects foreign URIs', () {
      expect(
          DigiLockerCallback.fromUri(
              Uri.parse('https://example.com/callback?code=x')),
          isNull);
      expect(
          DigiLockerCallback.fromUri(
              Uri.parse('polyticks://other/route')),
          isNull);
    });

    test('handler routes to registered listener and returns consumption',
        () {
      final handler = DeepLinkHandler.instance;
      Uri? received;
      final listener = _TestListener((uri) {
        received = uri;
        return true;
      });
      handler.register(listener);

      final mock =
          DeepLinkHandler.mockDigiLockerCallback('req-42', code: 'c1');
      expect(handler.handleUri(mock), isTrue);
      expect(received, mock);
      expect(received!.queryParameters['state'], 'req-42');

      handler.unregister(listener);
      // Unregistered → nobody consumes → false.
      expect(handler.handleUri(mock), isFalse);
    });
  });
}

class _TestListener implements DeepLinkListener {
  final bool Function(Uri uri) onUri;
  _TestListener(this.onUri);
  @override
  bool handleUri(Uri uri) => onUri(uri);
}
