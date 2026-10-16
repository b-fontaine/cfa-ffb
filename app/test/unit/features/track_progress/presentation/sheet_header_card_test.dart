import 'package:billard_cfa/features/track_progress/presentation/ui/sheet_header_card.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';
import '../../../../support/sheet_world.dart';
import '../../../shared/ui/pump_ui.dart';

/// Le bouton (Material) qui porte [text], icône comprise.
Finder buttonWith(String text) => find.ancestor(
  of: find.text(text),
  matching: find.bySubtype<ButtonStyleButton>(),
);

String title(ExerciseRef exercise) =>
    'Bloc ${exercise.blockId} · ex. ${exercise.number}';

void main() {
  late SheetWorld world;

  setUp(() async {
    world = SheetWorld();
    await world.start();
  });

  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<ExerciseRef>? onAcknowledge,
    ValueChanged<ExerciseRef>? onRestore,
  }) async {
    final sheet = await world.sheet(tester);
    await pumpUi(
      tester,
      SingleChildScrollView(
        child: SheetHeaderCard(
          header: sheet.header,
          titleOf: title,
          onAcknowledge: onAcknowledge,
          onRestore: onRestore,
        ),
      ),
    );
  }

  group('SheetHeaderCard', () {
    testWidgets('a fresh student has a path to start, never a score of zero', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Path to start'), findsOneWidget);
      expect(find.text('Exercise to start'), findsOneWidget);
      expect(find.text('Bloc a · ex. 1'), findsOneWidget);
      expect(find.text('Next exercise'), findsOneWidget);
      expect(find.text('Bloc a · ex. 2'), findsOneWidget);
      expect(find.textContaining('0 of'), findsNothing);
      expect(find.textContaining('0 exercises'), findsNothing);
    });

    testWidgets('counts the techniques completed and the exercises validated', (
      tester,
    ) async {
      for (var n = 1; n <= 3; n++) {
        await world.passes(ref('a', n), 5);
      }
      await world.passes(ref('b', 1), 5);
      await pump(tester);

      expect(find.text('1 of 3 techniques completed'), findsOneWidget);
      expect(find.text('4 exercises validated'), findsOneWidget);
      expect(find.text('Current exercise'), findsOneWidget);
      expect(find.text('Bloc b · ex. 2'), findsOneWidget);
      expect(find.text('Bloc b · ex. 3'), findsOneWidget);
    });

    testWidgets('writes the successful passes of the exercise in progress', (
      tester,
    ) async {
      await world.passes(ref('a', 1), 2);
      await pump(tester);

      expect(find.text('Current exercise'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('a finished level has neither current nor next exercise', (
      tester,
    ) async {
      for (final block in ['a', 'b', 'c']) {
        await world.acquire(block);
      }
      await pump(tester);

      expect(
        find.text('Level 1 completed: every exercise is validated.'),
        findsOneWidget,
      );
      expect(find.text('Current exercise'), findsNothing);
      expect(find.text('Next exercise'), findsNothing);
      expect(find.text('3 of 3 techniques completed'), findsOneWidget);
    });

    testWidgets('shows the most serious alert with a Seen button of 48 dp', (
      tester,
    ) async {
      await world.passes(ref('a', 1), 3, pass: false);
      ExerciseRef? seen;
      await pump(tester, onAcknowledge: (exercise) => seen = exercise);

      expect(find.text('Warning'), findsOneWidget);
      expect(
        find.text('Bloc a · ex. 1: 3 consecutive failures'),
        findsOneWidget,
      );
      final button = buttonWith('Seen');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(seen, ref('a', 1));
    });

    testWidgets('counts the other alerts instead of listing them', (
      tester,
    ) async {
      await world.passes(ref('a', 1), 5, pass: false);
      await world.passes(ref('b', 2), 3, pass: false);
      await pump(tester, onAcknowledge: (_) {});

      expect(find.text('Action needed'), findsOneWidget);
      expect(find.text('+ 1 other alert'), findsOneWidget);
    });

    testWidgets('offers no Seen button without a handler', (tester) async {
      await world.passes(ref('a', 1), 3, pass: false);
      await pump(tester);

      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Seen'), findsNothing);
    });

    testWidgets('a seen alert becomes a calm line that can be restored', (
      tester,
    ) async {
      await world.passes(ref('a', 1), 3, pass: false);
      await world.acknowledge(ref('a', 1));
      ExerciseRef? restored;
      await pump(
        tester,
        onAcknowledge: (_) {},
        onRestore: (exercise) => restored = exercise,
      );

      expect(find.text('Warning'), findsNothing);
      expect(find.text('Seen'), findsNothing);
      expect(
        find.text('Alert seen on Mon, Oct 5: Bloc a · ex. 1'),
        findsOneWidget,
      );
      final button = buttonWith('Restore');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(restored, ref('a', 1));
    });

    testWidgets('no alert line exists without any alert', (tester) async {
      await pump(tester, onAcknowledge: (_) {});

      expect(find.text('Warning'), findsNothing);
      expect(find.textContaining('No alert'), findsNothing);
    });
  });
}
