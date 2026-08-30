// ─────────────────────────────────────────────
//  Polyticks V4.0 – Deep Link Handler (B7)
// ─────────────────────────────────────────────
//
//  Routes `polyticks://` deep links to registered screens.
//
//  Supported routes:
//    polyticks://digilocker/callback?code=…&state=…   (B7: DigiLocker
//      OAuth2 redirect; state = verification_requests.id, verified against
//      the pending request before finalize)
//
//  PLATFORM BRIDGE STATUS (mock-first per V4 plan):
//    * The Dart-side routing here is production code and fully testable.
//    * The native bridge (app_links package + this manifest intent filter)
//      is the only missing piece — tracked as backlog B16. Until it lands,
//      the mock DigiLocker provider feeds synthetic callback URIs through
//      this exact path, so the flow is exercised end-to-end.

class DigiLockerCallback {
  final String? code;
  final String? state;
  const DigiLockerCallback({this.code, this.state});

  static DigiLockerCallback? fromUri(Uri uri) {
    if (uri.scheme != 'polyticks' ||
        uri.host != 'digilocker' ||
        uri.path != '/callback') {
      return null;
    }
    return DigiLockerCallback(
      code: uri.queryParameters['code'],
      state: uri.queryParameters['state'],
    );
  }
}

abstract class DeepLinkListener {
  /// Returns true when the link was consumed by this listener.
  bool handleUri(Uri uri);
}

class DeepLinkHandler {
  DeepLinkHandler._();
  static final DeepLinkHandler instance = DeepLinkHandler._();

  final List<DeepLinkListener> _listeners = [];

  void register(DeepLinkListener listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void unregister(DeepLinkListener listener) =>
      _listeners.remove(listener);

  /// Entry point for incoming app links. Native bridge calls this;
  /// tests and the mock DigiLocker provider call it directly.
  ///
  /// Returns true when some listener consumed the link.
  bool handleUri(Uri uri) {
    for (final listener in List.of(_listeners)) {
      if (listener.handleUri(uri)) return true;
    }
    return false;
  }

  /// MOCK PROVIDER (V4 plan: "add mockups where required"): simulates the
  /// DigiLocker consent → redirect round-trip by feeding a synthetic
  /// callback URI through the same production routing path. [requestId]
  /// becomes the OAuth2 state so CSRF verification runs for real.
  static Uri mockDigiLockerCallback(String requestId,
          {String code = 'mock-auth-code'}) =>
      Uri.parse(
          'polyticks://digilocker/callback?code=$code&state=$requestId');
}
