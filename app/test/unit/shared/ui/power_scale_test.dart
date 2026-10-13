import 'package:billard_cfa/shared/ui/power_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('writes one numbered bar per level', (tester) async {
    await pumpUi(tester, const PowerScale(levels: 3));

    for (var level = 1; level <= 3; level++) {
      expect(find.text('$level'), findsOneWidget);
    }
    expect(find.text('4'), findsNothing);
  });

  testWidgets('writes the five levels', (tester) async {
    await pumpUi(tester, const PowerScale(levels: 5));

    for (var level = 1; level <= 5; level++) {
      expect(find.text('$level'), findsOneWidget);
    }
  });

  testWidgets('marks only the highlighted level, with an icon', (tester) async {
    await pumpUi(tester, const PowerScale(levels: 5, highlight: 3));

    final marked = find.byKey(const ValueKey('power-highlight'));
    expect(marked, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('power-bar-3')),
        matching: marked,
      ),
      findsOneWidget,
    );
  });

  testWidgets('marks nothing without a highlight', (tester) async {
    await pumpUi(tester, const PowerScale(levels: 5));

    expect(find.byKey(const ValueKey('power-highlight')), findsNothing);
  });

  testWidgets('is spoken with the level in French', (tester) async {
    await pumpUi(
      tester,
      const PowerScale(levels: 5, highlight: 3),
      locale: const Locale('fr'),
    );

    expect(
      find.bySemanticsLabel('Échelle de puissance : niveau 3 sur 5'),
      findsOneWidget,
    );
  });

  testWidgets('is spoken as a range without a highlight, with the distance', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const PowerScale(levels: 4, distanceLabel: 'Jusqu’à la bande'),
    );

    expect(
      find.bySemanticsLabel('Power scale from 1 to 4. Jusqu’à la bande'),
      findsOneWidget,
    );
    expect(find.text('Jusqu’à la bande'), findsOneWidget);
  });

  testWidgets('names both ends of the scale', (tester) async {
    await pumpUi(
      tester,
      const PowerScale(levels: 5),
      locale: const Locale('fr'),
    );

    expect(find.text('Faible'), findsOneWidget);
    expect(find.text('Forte'), findsOneWidget);
  });

  test('rejects levels outside 1..5 and a highlight outside the scale', () {
    expect(() => PowerScale(levels: 0), throwsAssertionError);
    expect(() => PowerScale(levels: 6), throwsAssertionError);
    expect(() => PowerScale(levels: 3, highlight: 4), throwsAssertionError);
    expect(() => PowerScale(levels: 3, highlight: 0), throwsAssertionError);
  });

  testWidgets('does not overflow when narrow', (tester) async {
    await pumpUi(
      tester,
      const Center(
        child: SizedBox(
          width: 140,
          child: PowerScale(
            levels: 5,
            highlight: 5,
            distanceLabel: 'Un très long texte de distance',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('does not overflow with the text enlarged to 200 %', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Center(
          child: SizedBox(
            width: 320,
            child: PowerScale(levels: 5, highlight: 1, distanceLabel: 'Zone'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('power-bar-1')), findsOneWidget);
  });

  testWidgets('keeps the bars growing with the level at normal text size', (
    tester,
  ) async {
    await pumpUi(tester, const PowerScale(levels: 5));

    final heights = [
      for (var level = 1; level <= 5; level++)
        tester.getSize(find.byKey(ValueKey('power-bar-$level'))).height,
    ];
    expect(heights, orderedEquals([...heights]..sort()));
    expect(heights.first, lessThan(heights.last));
  });
}
