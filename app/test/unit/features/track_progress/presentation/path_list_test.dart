import 'package:billard_cfa/features/track_progress/presentation/ui/path_list.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/sheet_world.dart';
import '../../../shared/ui/pump_ui.dart';

void main() {
  late SheetWorld world;

  setUp(() async {
    world = SheetWorld();
    await world.start();
  });

  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<String>? onMark,
    ValueChanged<String>? onRevoke,
    ValueChanged<ExerciseRef>? onOpen,
  }) async {
    final sheet = await world.sheet(tester);
    await pumpUi(
      tester,
      SingleChildScrollView(
        child: PathList(
          sheet: sheet,
          onMarkAcquired: onMark,
          onRevokeAcquired: onRevoke,
          onOpenExercise: onOpen,
        ),
      ),
    );
  }

  String labelOf(WidgetTester tester, String key) =>
      tester.getSemantics(find.byKey(ValueKey(key))).label;

  group('PathList', () {
    testWidgets('has one row per technique and one cell per exercise', (
      tester,
    ) async {
      await pump(tester);

      for (final block in ['a', 'b', 'c']) {
        expect(find.byKey(ValueKey('path-row-$block')), findsOneWidget);
        expect(find.text('Bloc $block'), findsOneWidget);
        for (var n = 1; n <= 3; n++) {
          expect(find.byKey(ValueKey('path-cell-$block-$n')), findsOneWidget);
        }
      }
      expect(find.text('Path'), findsOneWidget);
      expect(find.text('9 exercises in total'), findsOneWidget);
    });

    testWidgets('names every cell with its state, never by colour', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await world.passes(ref('a', 1), 5);
      await world.passes(ref('a', 2), 2);
      await world.acquire('b');
      await pump(tester);

      expect(
        labelOf(tester, 'path-cell-a-1'),
        'Bloc a · exercise 1: validated',
      );
      expect(
        labelOf(tester, 'path-cell-a-2'),
        startsWith('Bloc a · exercise 2: started, 2 of 5 successful passes'),
      );
      expect(
        labelOf(tester, 'path-cell-a-3'),
        startsWith('Bloc a · exercise 3: to do'),
      );
      expect(
        labelOf(tester, 'path-cell-b-1'),
        'Bloc b · exercise 1: acquired at placement',
      );
      semantics.dispose();
    });

    testWidgets('marks the current exercise and an active alert', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await world.passes(ref('a', 1), 3, pass: false);
      await pump(tester);

      expect(
        labelOf(tester, 'path-cell-a-1'),
        'Bloc a · exercise 1: started, 0 of 5 successful passes, '
        'alert in progress, current exercise',
      );
      expect(find.byKey(const ValueKey('path-marker-alert')), findsOneWidget);
      expect(find.byKey(const ValueKey('path-marker-current')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a seen alert no longer marks its cell', (tester) async {
      await world.passes(ref('a', 1), 3, pass: false);
      await world.acknowledge(ref('a', 1));
      await pump(tester);

      expect(find.byKey(const ValueKey('path-marker-alert')), findsNothing);
    });

    testWidgets('writes the fraction of a row and reads its sessions aloud', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await world.passes(ref('a', 1), 5);
      await pump(tester);

      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('0/3'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('1 of 3 exercises · 1 session'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('0 of 3 exercises · no session'),
        findsNWidgets(2),
      );
      semantics.dispose();
    });

    testWidgets('writes a status only when it says more than started or not', (
      tester,
    ) async {
      for (var n = 1; n <= 3; n++) {
        await world.passes(ref('a', n), 5);
      }
      await world.acquire('b');
      await world.passes(ref('c', 1), 3, pass: false);
      await pump(tester);

      expect(find.text('Mastered'), findsOneWidget);
      expect(find.text('Acquired at placement'), findsOneWidget);
      expect(find.text('To review'), findsOneWidget);
      expect(find.text('In progress'), findsNothing);
      expect(find.text('Not started'), findsNothing);
    });

    testWidgets('writes the day and the taken-over exercises of a placement', (
      tester,
    ) async {
      await world.acquire('b');
      await pump(tester);

      expect(find.text('Acquired at placement'), findsOneWidget);
      expect(find.text('Acquired at placement on Thu, Oct 1'), findsOneWidget);
    });

    testWidgets('flags a technique worked more than recommended', (
      tester,
    ) async {
      await world.passes(ref('a', 1), 1);
      for (final day in [3, 4, 5]) {
        await world.world.session(id: 'more$day', dayOfMonth: day, main: 'a');
      }
      await pump(tester);

      expect(find.text('More sessions than recommended'), findsOneWidget);
    });

    testWidgets('tapping a cell reports its exercise', (tester) async {
      ExerciseRef? opened;
      await pump(tester, onOpen: (exercise) => opened = exercise);

      await tester.tap(find.byKey(const ValueKey('path-cell-b-2')));

      expect(opened, ref('b', 2));
    });

    testWidgets('cells are not buttons without a handler', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      final node = tester.getSemantics(
        find.byKey(const ValueKey('path-cell-b-2')),
      );
      expect(node.flagsCollection.isButton, isFalse);
      semantics.dispose();
    });

    testWidgets('keeps the placement actions in a menu per technique', (
      tester,
    ) async {
      String? marked;
      await pump(tester, onMark: (id) => marked = id, onRevoke: (_) {});

      expect(find.byTooltip('Placement actions: Bloc a'), findsOneWidget);
      expect(find.text('Mark block as acquired'), findsNothing);
      await tester.tap(find.byTooltip('Placement actions: Bloc a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark block as acquired'));
      await tester.pumpAndSettle();

      expect(marked, 'a');
    });

    testWidgets('an acquired technique offers to remove the status', (
      tester,
    ) async {
      String? revoked;
      await world.acquire('a');
      await pump(tester, onMark: (_) {}, onRevoke: (id) => revoked = id);

      await tester.tap(find.byTooltip('Placement actions: Bloc a'));
      await tester.pumpAndSettle();
      expect(find.text('Mark block as acquired'), findsNothing);
      await tester.tap(find.text('Remove acquired status'));
      await tester.pumpAndSettle();

      expect(revoked, 'a');
    });

    testWidgets('a technique mastered by passes has no placement menu', (
      tester,
    ) async {
      for (var n = 1; n <= 3; n++) {
        await world.passes(ref('a', n), 5);
      }
      await pump(tester, onMark: (_) {}, onRevoke: (_) {});

      expect(find.byTooltip('Placement actions: Bloc a'), findsNothing);
      expect(find.byTooltip('Placement actions: Bloc b'), findsOneWidget);
    });

    testWidgets('has no menu without placement handlers', (tester) async {
      await pump(tester);

      expect(find.byTooltip('Placement actions: Bloc a'), findsNothing);
    });

    testWidgets('every cell and every menu is at least 48 dp', (tester) async {
      await pump(tester, onMark: (_) {}, onRevoke: (_) {}, onOpen: (_) {});

      for (final block in ['a', 'b', 'c']) {
        final menu = tester.getSize(
          find.byTooltip('Placement actions: Bloc $block'),
        );
        expect(menu.width, greaterThanOrEqualTo(48));
        expect(menu.height, greaterThanOrEqualTo(48));
        for (var n = 1; n <= 3; n++) {
          final size = tester.getSize(
            find.byKey(ValueKey('path-cell-$block-$n')),
          );
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
      }
    });
  });
}
