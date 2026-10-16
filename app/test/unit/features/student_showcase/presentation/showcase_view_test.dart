import 'package:billard_cfa/features/student_showcase/presentation/ui/showcase_view.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
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

  Future<void> pump(WidgetTester tester) async {
    final showcase = await world.showcase(tester);
    await pumpUi(
      tester,
      SingleChildScrollView(child: ShowcaseView(showcase: showcase)),
    );
  }

  group('ShowcaseView', () {
    testWidgets('shows the first name and the whole path', (tester) async {
      await pump(tester);

      expect(find.text('s1'), findsOneWidget);
      for (var row = 0; row < 3; row++) {
        expect(find.byKey(ValueKey('showcase-row-$row')), findsOneWidget);
        for (var n = 1; n <= 3; n++) {
          expect(find.byKey(ValueKey('showcase-cell-$row-$n')), findsOneWidget);
        }
      }
      expect(find.text('Bloc a'), findsOneWidget);
      expect(find.text('9 exercises in total'), findsOneWidget);
    });

    testWidgets('says the path is to start only before any attempt', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Path to start'), findsOneWidget);

      await world.passes(ref('a', 1), 2, pass: false);
      await pump(tester);

      expect(find.text('Path to start'), findsNothing);
    });

    testWidgets('names each cell by its state', (tester) async {
      final semantics = tester.ensureSemantics();
      await world.passes(ref('a', 1), 5);
      await world.passes(ref('a', 2), 2);
      await world.acquire('b');
      await pump(tester);

      String label(String key) =>
          tester.getSemantics(find.byKey(ValueKey(key))).label;
      expect(label('showcase-cell-0-1'), 'Bloc a · exercise 1: validated');
      expect(
        label('showcase-cell-0-2'),
        startsWith('Bloc a · exercise 2: started, 2 of 5 successful passes'),
      );
      expect(label('showcase-cell-0-3'), 'Bloc a · exercise 3: to do');
      expect(
        label('showcase-cell-1-1'),
        'Bloc b · exercise 1: acquired at placement',
      );
      semantics.dispose();
    });

    testWidgets('writes the status of each technique in text', (tester) async {
      await world.passes(ref('a', 1), 1);
      await world.acquire('b');
      await pump(tester);

      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Acquired at placement'), findsOneWidget);
      expect(find.text('Not started'), findsOneWidget);
    });

    testWidgets('puts the exercise in progress first, with successful passes', (
      tester,
    ) async {
      await world.passes(ref('a', 1), 2);
      await world.passes(ref('a', 1), 2, pass: false);
      await pump(tester);

      expect(find.text('Your current exercise'), findsOneWidget);
      expect(find.text('Bloc a · exercise 1'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Your current exercise')).dy,
        lessThan(tester.getTopLeft(find.text('Bloc a')).dy),
      );
    });

    testWidgets('a student with nothing validated has a path to start', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Path to start'), findsOneWidget);
      expect(find.textContaining('0 of'), findsNothing);
    });

    testWidgets('counts the techniques completed and the exercises validated', (
      tester,
    ) async {
      for (var n = 1; n <= 3; n++) {
        await world.passes(ref('a', n), 5);
      }
      await pump(tester);

      expect(find.text('1 of 3 techniques completed'), findsOneWidget);
      expect(find.text('3 exercises validated'), findsOneWidget);
      expect(find.text('Mastered'), findsOneWidget);
    });

    testWidgets('a finished level has no exercise in progress', (tester) async {
      for (final block in ['a', 'b', 'c']) {
        await world.acquire(block);
      }
      await pump(tester);

      expect(find.text('Level 1 completed'), findsOneWidget);
      expect(find.text('Your current exercise'), findsNothing);
    });

    testWidgets('does not flag a proposal technique as a proposal', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      world = SheetWorld(
        catalogue: buildCatalogue([
          block('a', 1, source: Provenance.prop),
          block('b', 2),
        ]),
      );
      await world.start();
      await pump(tester);

      expect(find.text('Bloc a'), findsOneWidget);
      expect(find.text('Proposal'), findsNothing);
      expect(find.textContaining('Proposal'), findsNothing);
      final label = tester
          .getSemantics(find.byKey(const ValueKey('showcase-cell-0-1')))
          .label;
      expect(label, isNot(contains('Proposal')));
      expect(label, startsWith('Bloc a · exercise 1'));
      semantics.dispose();
    });

    testWidgets('shows neither alert nor failure nor action', (tester) async {
      await world.passes(ref('a', 1), 5, pass: false);
      await pump(tester);

      expect(find.text('Action needed'), findsNothing);
      expect(find.text('Warning'), findsNothing);
      expect(find.text('To review'), findsNothing);
      expect(find.text('Seen'), findsNothing);
      expect(find.textContaining('failure'), findsNothing);
      expect(find.byType(ButtonStyleButton), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('showcase-row-0')),
          matching: find.byType(InkResponse),
        ),
        findsNothing,
      );
      expect(find.text('In progress'), findsOneWidget);
    });
  });
}
