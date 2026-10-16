import 'package:billard_cfa/shared/ui/watch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('shows the name, the detail and the level in words', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const WatchRow(
        name: 'Léa',
        detail: 'Posture · exercise 1 · 3 failures in a row',
        persistent: false,
      ),
    );

    expect(find.text('Léa'), findsOneWidget);
    expect(find.textContaining('3 failures in a row'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
  });

  testWidgets('writes the persistent level as Action needed', (tester) async {
    await pumpUi(
      tester,
      const WatchRow(name: 'Léa', detail: 'd', persistent: true),
    );

    expect(find.text('Action needed'), findsOneWidget);
  });

  testWidgets('is at least 48 dp high and taps through', (tester) async {
    var taps = 0;
    await pumpUi(
      tester,
      WatchRow(
        name: 'Léa',
        detail: 'd',
        persistent: false,
        onTap: () => taps++,
      ),
    );

    expect(
      tester.getSize(find.byType(InkWell)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Léa'));
    expect(taps, 1);
  });

  testWidgets('announces the whole line as one label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      const WatchRow(name: 'Léa', detail: 'Posture', persistent: false),
    );

    expect(find.bySemanticsLabel('Léa, Posture, Warning'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('announces the line in French with the French level', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      const WatchRow(name: 'Léa', detail: 'Posture', persistent: true),
      locale: const Locale('fr'),
    );

    expect(find.bySemanticsLabel('Léa, Posture, À traiter'), findsOneWidget);
    handle.dispose();
  });
}
