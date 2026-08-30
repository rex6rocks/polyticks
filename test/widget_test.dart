import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/main.dart';

void main() {
  testWidgets('Polyticks app smoke test - Login Flow',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PolyticksApp());

    // Verify that we are on the login screen by finding 'Welcome back'
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);

    // Find the email and password fields
    final emailField = find.byType(TextFormField).first;
    final passwordField = find.byType(TextFormField).last;

    // Enter Janta demo credentials
    await tester.enterText(emailField, 'arjun@janta.in');
    await tester.enterText(passwordField, 'janta123');

    // Tap the 'Sign In' button and trigger a frame
    final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
    expect(signInButton, findsOneWidget);

    // Ensure the button is visible before tapping
    await tester.ensureVisible(signInButton);
    await tester.pumpAndSettle();

    await tester.tap(signInButton);

    // Wait for the simulated network delay (800ms in login screen)
    await tester.pump(const Duration(seconds: 1));

    // Wait for route transition and greeting animations (3+ seconds in feed screen)
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Verify that we are now on the Feed Screen by finding 'Your Feed'
    expect(find.text('Your Feed'), findsWidgets);

    // Wait for the greeting to disappear (it hides after 3 seconds)
    await tester.pump(const Duration(seconds: 4));
  });
}
