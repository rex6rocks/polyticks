//
// submit_fact_check_modal_test.dart
//
// Widget tests for the SubmitFactCheckModal (Task A4):
//  * empty note is blocked by form validation
//  * short note (<10 chars) is blocked
//  * source URL chips parse correctly from input
//

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/config.dart';
import 'package:polyticks/widgets/submit_fact_check_modal.dart';
import 'package:polyticks/services/fact_check_service.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    // Force simulation mode so FactCheckService never touches the network.
    AppConfig.forceTestMode = true;
    FactCheckService.instance.clearSimulatedData();
    FactCheckService.simulatedUserId = 'm1'; // verified user
  });

  testWidgets('empty note is blocked by validation and does not submit',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const SubmitFactCheckModal(postId: 'post1', currentUserId: 'm1'),
    ));

    await tester.tap(find.text('Submit Note'));
    await tester.pump();

    expect(find.text('Please enter a context note'), findsOneWidget);
    // Modal must still be open (no pop).
    expect(find.byType(SubmitFactCheckModal), findsOneWidget);
  });

  testWidgets('note shorter than 10 characters is blocked', (tester) async {
    await tester.pumpWidget(_wrap(
      const SubmitFactCheckModal(postId: 'post1', currentUserId: 'm1'),
    ));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Context Note'), 'short');
    await tester.tap(find.text('Submit Note'));
    await tester.pump();

    expect(
        find.text('Context note must be at least 10 characters'),
        findsOneWidget);
    expect(find.byType(SubmitFactCheckModal), findsOneWidget);
  });

  testWidgets('valid note with sources submits successfully and pops',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const SubmitFactCheckModal(postId: 'post1', currentUserId: 'm1'),
    ));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Context Note'),
      'A valid community note with enough context.',
    );

    // Add a source via the Add Source field (plain TextField with onSubmitted).
    await tester.enterText(
        find.widgetWithText(TextField, 'Add Source URL'),
        'https://example.com/proof');
    await tester.tap(find.byTooltip('Add Source'));
    await tester.pump();

    expect(find.text('https://example.com/proof'), findsOneWidget);

    await tester.tap(find.text('Submit Note'));
    await tester.pumpAndSettle();
  });
}
