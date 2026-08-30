// ─────────────────────────────────────────────
//  Polyticks – App Entry Point
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'models/models.dart';
import 'config.dart';
import 'services/supabase_service.dart';
import 'services/fact_check_service.dart';
import 'services/deep_link_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/id_verification_screen.dart';
import 'screens/feed/feed_screen.dart';
import 'screens/admin/admin_console_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize backend (real Supabase if configured, otherwise Simulation).
  await SupabaseService.instance.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  // V4.0 B16: bridge native app links (polyticks://digilocker/callback …)
  // into the Dart-side DeepLinkHandler. Errors are non-fatal — platforms
  // without deep-link support simply never receive links.
  _bindAppLinks();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  // DEBUG: diagnose unbounded web view width (infinite-width layout crash)
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  debugPrint('Polyticks view physicalSize=${view.physicalSize} dpr=${view.devicePixelRatio}');

  runApp(const ProviderScope(child: PolyticksApp()));
}

void _bindAppLinks() {
  try {
    final links = AppLinks();
    // Cold start: app opened directly via a deep link.
    links.getInitialLink().then((uri) {
      if (uri != null) DeepLinkHandler.instance.handleUri(uri);
    }).catchError((_) {});
    // Warm start: link arrives while app is running/resumed.
    links.uriLinkStream.listen(
      (uri) => DeepLinkHandler.instance.handleUri(uri),
      onError: (_) {},
    );
  } catch (e) {
    debugPrint('AppLinks bridge unavailable: $e');
  }
}

class PolyticksApp extends StatefulWidget {
  const PolyticksApp({super.key});

  @override
  State<PolyticksApp> createState() => _PolyticksAppState();
}

class _PolyticksAppState extends State<PolyticksApp> {
  AppUser? _currentUser;
  bool _showIdVerification = false;

  void _onLogin(AppUser user) {
    FactCheckService.simulatedUserId = user.id;
    setState(() {
      _currentUser = user;
      // Step 1: Only unverified Janta users who are NOT guests need to go through ID verification
      _showIdVerification = user.role == UserRole.janta && !user.isVerified && !user.isGuest;
    });
  }

  void _onContinueFromVerification() {
    setState(() => _showIdVerification = false);
  }

  void _onLogout() {
    setState(() {
      _currentUser = null;
      _showIdVerification = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (_currentUser == null) {
      home = LoginScreen(onLogin: _onLogin);
    } else if (_currentUser!.role == UserRole.admin) {
      home = AdminConsoleScreen(onLogout: _onLogout);
    } else if (_showIdVerification) {
      home = IdVerificationScreen(
        currentUser: _currentUser!,
        onContinue: _onContinueFromVerification,
      );
    } else {
      home = FeedScreen(
        currentUser: _currentUser!,
        onLogout: _onLogout,
      );
    }

    return MaterialApp(
      title: 'Polyticks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: home,
    );
  }
}

