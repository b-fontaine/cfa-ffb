import 'package:billard_cfa/shared/ui/closure_choice_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool erase,
    ValueChanged<bool>? onChanged,
    Locale locale = const Locale('en'),
  }) => pumpUi(
    tester,
    ClosureChoiceTile(
      name: 'Hugo',
      reason: 'Absent from every session this season',
      erase: erase,
      onChanged: onChanged ?? (_) {},
    ),
    locale: locale,
  );

  testWidgets('shows the name, the reason and the choice in words', (
    tester,
  ) async {
    await pump(tester, erase: true);

    expect(find.text('Hugo'), findsOneWidget);
    expect(find.text('Absent from every session this season'), findsOneWidget);
    expect(find.text('Erase'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('says Keep when the student is kept', (tester) async {
    await pump(tester, erase: false);

    expect(find.text('Keep'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('its accessible name carries the first name and the choice', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, erase: true);

    expect(find.bySemanticsLabel('Hugo: Erase'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('is spoken in French', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, erase: false, locale: const Locale('fr'));

    expect(find.bySemanticsLabel('Hugo : Reconduire'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a tap anywhere on the row flips the choice', (tester) async {
    bool? received;
    await pump(tester, erase: false, onChanged: (value) => received = value);

    await tester.tap(find.text('Hugo'));

    expect(received, isTrue);
  });

  testWidgets('the switch itself flips the choice', (tester) async {
    bool? received;
    await pump(tester, erase: true, onChanged: (value) => received = value);

    await tester.tap(find.byType(Switch));

    expect(received, isFalse);
  });

  testWidgets('the row is at least 48 dp high', (tester) async {
    await pump(tester, erase: false);

    expect(
      tester.getSize(find.byType(ClosureChoiceTile)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
