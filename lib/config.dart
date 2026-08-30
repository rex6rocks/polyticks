// ─────────────────────────────────────────────
//  Polyticks – App Configuration
// ─────────────────────────────────────────────
//
//  Secrets are injected at build/run time via --dart-define so they are
//  NEVER committed to source control.
//
//  Run with real Supabase credentials:
//    flutter run \
//      --dart-define=SUPABASE_URL=https://YOURPROJECT.supabase.co \
//      --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
//
//  With empty values (default) the app runs in SIMULATION mode, backed by
//  the in-memory mock engine, so the UI is fully explorable with no backend.

class AppConfig {
  AppConfig._();

  /// Your Supabase project URL (e.g. https://xyzcompany.supabase.co)
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  /// Your Supabase publishable (anon) key.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Internal flag to force test mode in tests.
  static bool _forceTestMode = false;

  /// True when real Supabase credentials were supplied at build time.
  static bool get isSupabaseConfigured =>
      !_forceTestMode && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Forces test mode for testing purposes.
  static set forceTestMode(bool value) => _forceTestMode = value;

  /// Private storage bucket name that holds identity documents.
  static const String idVerificationBucket = 'id-verifications';

  /// Public storage bucket name that holds post media.
  static const String postMediaBucket = 'post-media';

  /// API Key for Groq moderation (optional, injected via --dart-define=GROQ_API_KEY)
  ///
  /// ⚠️ KEY HYGIENE NOTE (V2 Task C1 / pre-prod audit item):
  /// `--dart-define` values are embedded in the shipped client binary and can
  /// be extracted. Acceptable for ALPHA only. Before production, screening
  /// MUST move behind a Supabase Edge Function proxy so GROQ_API_KEY never
  /// ships in client builds.
  static const String groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  /// Returns true if Groq API key is configured.
  /// [forceGroqConfigured] lets tests simulate a configured/unconfigured key
  /// without recompiling with different --dart-define values.
  static bool? forceGroqConfigured;
  static bool get isGroqConfigured =>
      forceGroqConfigured ?? groqApiKey.isNotEmpty;

  /// Returns true if Hugging Face API token is configured.
  static bool get isHfConfigured => hfApiToken.isNotEmpty;


  /// API Token for Hugging Face Inference (optional, injected via --dart-define=HF_API_TOKEN)
  static const String hfApiToken =
      String.fromEnvironment('HF_API_TOKEN', defaultValue: '');

  // ─────────────────────────────────────────────
  //  V4.0 – Scale & Monetization Flags
  // ─────────────────────────────────────────────
  //
  //  PRO-READY SEAMS (see docs/V4_SPEC.md § Pro Upgrade Runbook):
  //  The app ships entirely on Supabase FREE tier. When the first org is
  //  ready to pay post-release, the upgrade is config-only:
  //    1. --dart-define=SUPABASE_TIER=pro   (+ Supabase dashboard upgrade)
  //    2. --dart-define=RAZORPAY_KEY_ID=<live key>
  //    3. Flip priorityBroadcastEnabled / relax analytics retention.
  //  No schema, service, or widget changes required.

  /// Current infrastructure tier. 'free' during v4.0 launch; 'pro' after the
  /// first paid org triggers the upgrade update.
  static const String supabaseTier =
      String.fromEnvironment('SUPABASE_TIER', defaultValue: 'free');

  /// True once the project has been upgraded to Supabase Pro.
  static bool get isProTier => supabaseTier == 'pro';

  /// Razorpay key id (test mode until launch of paid tier).
  /// Test key: --dart-define=RAZORPAY_KEY_ID=rzp_test_xxxx
  static const String razorpayKeyId =
      String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: '');

  /// Whether a payment provider is configured (checkout UI gate).
  static bool get isPaymentsConfigured => razorpayKeyId.isNotEmpty;

  /// Priority push broadcasts for paid orgs. Placeholder OFF on free tier —
  /// flip to true in the post-release Pro update.
  static const String _priorityBroadcastRaw = String.fromEnvironment(
      'PRIORITY_BROADCAST_ENABLED',
      defaultValue: '');
  static bool get priorityBroadcastEnabled =>
      _priorityBroadcastRaw == 'true' && isProTier;

  /// DigiLocker automated verification master switch. Stays false until
  /// govt sandbox approval lands; mock provider used for dev/tests meanwhile.
  static const String digilockerBaseUrl =
      String.fromEnvironment('DIGILOCKER_BASE_URL', defaultValue: '');
  static bool get isDigilockerEnabled =>
      digilockerBaseUrl.isNotEmpty || _forceTestMode;
}
