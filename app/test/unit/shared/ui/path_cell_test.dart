import 'package:billard_cfa/shared/ui/path_cell.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  Widget cell(
    PathCellState state, {
    int passed = 0,
    bool alerted = false,
    bool current = false,
    VoidCallback? onTap,
  }) => PathCell(
    key: const ValueKey('cell'),
    state: state,
    label: 'Posture · exercise 1: ${state.name}',
    passed: passed,
    alerted: alerted,
    current: current,
    onTap: onTap,
  );

  group('PathCell', () {
    testWidgets('is a touch target of at least 48 dp in every state', (
      tester,
    ) async {
      for (final state in PathCellState.values) {
        await pumpUi(tester, Center(child: cell(state, onTap: () {})));
        final size = tester.getSize(find.byKey(const ValueKey('cell')));
        expect(size.width, greaterThanOrEqualTo(48), reason: '$state');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$state');
      }
    });

    testWidgets('draws one distinct glyph per state', (tester) async {
      for (final state in PathCellState.values) {
        await pumpUi(tester, cell(state));
        expect(
          find.byKey(ValueKey('path-glyph-${state.name}')),
          findsOneWidget,
          reason: '$state',
        );
      }
    });

    testWidgets('shows a tick when validated and a flag when acquired', (
      tester,
    ) async {
      await pumpUi(tester, cell(PathCellState.validated));
      expect(find.byIcon(Icons.check), findsOneWidget);
      await pumpUi(tester, cell(PathCellState.acquired));
      expect(find.byIcon(Icons.bookmark_added), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      await pumpUi(tester, cell(PathCellState.todo));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('a started cell writes its successful passes', (tester) async {
      await pumpUi(tester, cell(PathCellState.started, passed: 2));
      expect(find.text('2'), findsOneWidget);
      await pumpUi(tester, cell(PathCellState.started));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('an alert is an attention icon, never a red state', (
      tester,
    ) async {
      await pumpUi(
        tester,
        cell(PathCellState.started, passed: 1, alerted: true, onTap: () {}),
      );
      expect(find.byKey(const ValueKey('path-marker-alert')), findsOneWidget);
      final scheme = AppTheme.light().colorScheme;
      final reds = {scheme.error, scheme.errorContainer};
      for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('cell')),
          matching: find.byType(DecoratedBox),
        ),
      )) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(reds, isNot(contains(decoration.color)));
        }
      }
    });

    testWidgets('the current exercise is ringed', (tester) async {
      await pumpUi(tester, cell(PathCellState.todo, current: true));
      expect(find.byKey(const ValueKey('path-marker-current')), findsOneWidget);
      await pumpUi(tester, cell(PathCellState.todo));
      expect(find.byKey(const ValueKey('path-marker-current')), findsNothing);
    });

    testWidgets('is named by its label and is a button only when tappable', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpUi(tester, cell(PathCellState.validated, onTap: () {}));
      var node = tester.getSemantics(find.byKey(const ValueKey('cell')));
      expect(node.label, 'Posture · exercise 1: validated');
      expect(node.flagsCollection.isButton, isTrue);

      await pumpUi(tester, cell(PathCellState.validated));
      node = tester.getSemantics(find.byKey(const ValueKey('cell')));
      expect(node.label, 'Posture · exercise 1: validated');
      expect(node.flagsCollection.isButton, isFalse);
      semantics.dispose();
    });

    testWidgets('tapping reports the tap', (tester) async {
      var taps = 0;
      await pumpUi(
        tester,
        Center(child: cell(PathCellState.todo, onTap: () => taps++)),
      );
      await tester.tap(find.byKey(const ValueKey('cell')));
      expect(taps, 1);
    });
  });

  group('PathLegend', () {
    testWidgets('names the four states and the exercise total in text', (
      tester,
    ) async {
      await pumpUi(tester, const PathLegend(exerciseCount: 70));
      expect(find.text('To do'), findsOneWidget);
      expect(find.text('Started'), findsOneWidget);
      expect(find.text('Validated'), findsOneWidget);
      expect(find.text('From placement'), findsOneWidget);
      expect(find.text('70 exercises in total'), findsOneWidget);
    });

    testWidgets('draws the glyph of every state', (tester) async {
      await pumpUi(tester, const PathLegend(exerciseCount: 4));
      for (final state in PathCellState.values) {
        expect(
          find.byKey(ValueKey('path-glyph-${state.name}')),
          findsOneWidget,
        );
      }
    });
  });
}
