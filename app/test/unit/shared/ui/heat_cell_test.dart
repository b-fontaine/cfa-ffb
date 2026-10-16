import 'package:billard_cfa/shared/ui/heat_cell.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  Widget cell(
    HeatLevel level, {
    bool acquired = false,
    bool alerted = false,
    VoidCallback? onTap,
  }) => HeatCell(
    key: const ValueKey('heat'),
    fraction: '3/4',
    level: level,
    label: 'Léa, Posture: 3 of 4 exercises, In progress',
    acquired: acquired,
    alerted: alerted,
    onTap: onTap,
  );

  group('HeatCell', () {
    testWidgets('always writes the fraction, whatever the level', (
      tester,
    ) async {
      for (final level in HeatLevel.values) {
        await pumpUi(tester, cell(level));
        expect(find.text('3/4'), findsOneWidget, reason: '$level');
      }
    });

    testWidgets('is a touch target of at least 48 dp', (tester) async {
      for (final level in HeatLevel.values) {
        await pumpUi(tester, Center(child: cell(level, onTap: () {})));
        final size = tester.getSize(find.byKey(const ValueKey('heat')));
        expect(size.width, greaterThanOrEqualTo(48), reason: '$level');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$level');
      }
    });

    testWidgets('four levels give four different fills', (tester) async {
      final fills = <Color?>{};
      for (final level in HeatLevel.values) {
        await pumpUi(tester, cell(level));
        final box = tester.widget<DecoratedBox>(
          find.byKey(ValueKey('heat-fill-${level.name}')),
        );
        fills.add((box.decoration as BoxDecoration).color);
      }
      expect(fills, hasLength(HeatLevel.values.length));
    });

    testWidgets('a completed cell shows a tick next to the fraction', (
      tester,
    ) async {
      await pumpUi(tester, cell(HeatLevel.all));
      expect(find.byIcon(Icons.check), findsOneWidget);
      await pumpUi(tester, cell(HeatLevel.most));
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('an acquired cell shows a flag and an alert a warning', (
      tester,
    ) async {
      await pumpUi(tester, cell(HeatLevel.all, acquired: true));
      expect(find.byIcon(Icons.bookmark_added), findsOneWidget);
      await pumpUi(tester, cell(HeatLevel.some, alerted: true));
      expect(find.byKey(const ValueKey('heat-marker-alert')), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_added), findsNothing);
    });

    testWidgets('never uses the error colours', (tester) async {
      final scheme = AppTheme.light().colorScheme;
      final reds = {scheme.error, scheme.errorContainer};
      for (final level in HeatLevel.values) {
        await pumpUi(tester, cell(level, alerted: true, acquired: true));
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('heat')),
            matching: find.byType(DecoratedBox),
          ),
        )) {
          final decoration = box.decoration;
          if (decoration is BoxDecoration) {
            expect(reds, isNot(contains(decoration.color)));
          }
        }
      }
    });

    testWidgets('is named by its label and is a button only when tappable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpUi(tester, cell(HeatLevel.some, onTap: () {}));
      var node = tester.getSemantics(find.byKey(const ValueKey('heat')));
      expect(node.label, 'Léa, Posture: 3 of 4 exercises, In progress');
      expect(node.flagsCollection.isButton, isTrue);
      await pumpUi(tester, cell(HeatLevel.some));
      node = tester.getSemantics(find.byKey(const ValueKey('heat')));
      expect(node.flagsCollection.isButton, isFalse);
      semantics.dispose();
    });

    testWidgets('tapping reports the tap', (tester) async {
      var taps = 0;
      await pumpUi(
        tester,
        Center(child: cell(HeatLevel.none, onTap: () => taps++)),
      );
      await tester.tap(find.byKey(const ValueKey('heat')));
      expect(taps, 1);
    });
  });
}
