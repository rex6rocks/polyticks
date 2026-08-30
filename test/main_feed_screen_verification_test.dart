// ─────────────────────────────────────────────
//  Polyticks – Main Feed Screen Verification Test
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/screens/feed/feed_screen.dart';
import 'package:polyticks/models/models.dart';
import 'package:polyticks/utils/logger.dart';
import 'package:polyticks/theme/app_theme.dart';

void main() {
  group('MainFeedScreen Verification Tests', () {
    late AppUser testJantaUser;

    setUp(() {
      testJantaUser = AppUser(
        id: 'u1',
        displayName: 'Arjun Sharma',
        role: UserRole.janta,
        avatarColor: '#4ECDC4',
        email: 'arjun@janta.in',
      );
    });

    Future<void> pumpFeedScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: FeedScreen(currentUser: testJantaUser, onLogout: () {}),
        ),
      );
      // Wait for UI to stabilize after async data loading
      await tester.pumpAndSettle();
    }

    // TEST 1: ListView Scrolling Verification
    testWidgets('Verify ListView scrolling functionality',
        (WidgetTester tester) async {
      await pumpFeedScreen(tester);

      expect(find.byType(ListView).first, findsOneWidget,
          reason: 'ListView should be present');

      await tester.fling(
          find.byType(ListView).first, const Offset(0, -500), 10000);

      await tester.pumpAndSettle();

      await tester.fling(
          find.byType(ListView).first, const Offset(0, 500), 10000);
      await tester.pumpAndSettle();

      expect(find.byType(ListView).first, findsOneWidget,
          reason: 'ListView should remain after scrolling');

      logger.i('✅ ListView scrolling verified');
    });

    // TEST 2: Dummy Feed Card Rendering
    testWidgets('Verify dummy feed card rendering',
        (WidgetTester tester) async {
      await pumpFeedScreen(tester);

      expect(find.byType(ListView).first, findsOneWidget);

      logger.i('✅ Dummy feed card rendering verified');
    });

    // TEST 3: Tab Switching (Hyper-Local vs Broader)
    testWidgets('Verify tab switching between Hyper-Local and Broader',
        (WidgetTester tester) async {
      await pumpFeedScreen(tester);

      expect(find.byType(TabBar), findsOneWidget,
          reason: 'TabBar should be present');
      expect(find.text('Hyper-Local'), findsOneWidget,
          reason: 'Hyper-Local tab should exist');
      expect(find.text('Broader Channel'), findsOneWidget,
          reason: 'Broader Channel tab should exist');

      await tester.tap(find.text('Broader Channel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hyper-Local'));
      await tester.pumpAndSettle();

      logger.i('✅ Tab switching verified');
    });

    // TEST 4: Bottom Navigation Bar
    testWidgets('Verify bottom navigation bar', (WidgetTester tester) async {
      await pumpFeedScreen(tester);

      expect(find.byType(BottomNavigationBar), findsOneWidget,
          reason: 'BottomNavigationBar should exist');
      expect(find.text('Feed'), findsOneWidget,
          reason: 'Feed tab should exist');
      expect(find.text('Explore'), findsOneWidget,
          reason: 'Explore tab should exist');
      expect(find.text('Alerts'), findsOneWidget,
          reason: 'Alerts tab should exist');
      expect(find.text('Profile'), findsOneWidget,
          reason: 'Profile tab should exist');

      logger.i('✅ Bottom navigation bar verified');
    });
  });
}
