import 'package:billard_cfa/shared/ui/cell_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

CellGrid grid({
  int students = 3,
  int techniques = 2,
  ValueChanged<String>? onColumnTap,
  bool footer = false,
}) => CellGrid(
  keyPrefix: 'heat',
  semanticLabel: 'Techniques by student',
  columns: [
    for (var s = 0; s < students; s++)
      CellGridColumn(
        id: 's$s',
        label: 'Student $s',
        semanticLabel: 'Open the sheet of Student $s',
        onTap: onColumnTap == null ? null : () => onColumnTap('s$s'),
      ),
  ],
  rows: [
    for (var t = 0; t < techniques; t++)
      CellGridRow(
        id: 't$t',
        header: 'Technique $t with a rather long title that wraps',
        semanticLabel: 'Technique $t: 1 of $students students completed',
        cells: [for (var s = 0; s < students; s++) Text('c$t-$s')],
      ),
  ],
  footer: footer
      ? CellGridRow(
          id: 'attendance',
          header: 'Attendance',
          semanticLabel: 'Attendance of the group',
          cells: [for (var s = 0; s < students; s++) Text('a$s')],
        )
      : null,
);

void main() {
  group('CellGrid', () {
    testWidgets('lays out one row per technique and one column per student', (
      tester,
    ) async {
      await pumpUi(tester, grid());
      expect(find.byKey(const ValueKey('heat-row-t0')), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-row-t1')), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-column-s0')), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-column-s2')), findsOneWidget);
      expect(find.text('c1-2'), findsOneWidget);
      expect(find.text('Student 1'), findsOneWidget);
    });

    testWidgets('the cell of a row sits under the column of its student', (
      tester,
    ) async {
      await pumpUi(tester, grid());
      for (var s = 0; s < 3; s++) {
        final column = tester.getCenter(
          find.byKey(ValueKey('heat-column-s$s')),
        );
        final cell = tester.getCenter(find.text('c0-$s'));
        expect((cell.dx - column.dx).abs(), lessThan(1));
      }
      final r0 = tester.getCenter(find.text('c0-0')).dy;
      final r1 = tester.getCenter(find.text('c1-0')).dy;
      expect(r1, greaterThan(r0));
      final header0 = tester.getCenter(
        find.byKey(const ValueKey('heat-technique-t0')),
      );
      expect((header0.dy - r0).abs(), lessThan(1));
    });

    testWidgets('keeps the technique column in place while students scroll', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpUi(tester, grid(students: 12));
      final technique = find.byKey(const ValueKey('heat-technique-t0'));
      final student = find.byKey(const ValueKey('heat-column-s0'));
      final techniqueBefore = tester.getTopLeft(technique);
      final studentBefore = tester.getTopLeft(student);

      await tester.drag(
        find.byKey(const ValueKey('heat-scroll')),
        const Offset(-250, 0),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(technique), techniqueBefore);
      expect(tester.getTopLeft(student).dx, lessThan(studentBefore.dx));
    });

    testWidgets('a student header opens the student when a tap is given', (
      tester,
    ) async {
      String? tapped;
      await pumpUi(tester, grid(onColumnTap: (id) => tapped = id));
      await tester.tap(find.byKey(const ValueKey('heat-column-s1')));
      expect(tapped, 's1');
      final size = tester.getSize(find.byKey(const ValueKey('heat-column-s1')));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('describes every row and column as text for screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpUi(tester, grid(onColumnTap: (_) {}));
      expect(
        find.bySemanticsLabel('Technique 0: 1 of 3 students completed'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Open the sheet of Student 2'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Techniques by student'), findsWidgets);
      semantics.dispose();
    });

    testWidgets('adds a footer row aligned with the columns', (tester) async {
      await pumpUi(tester, grid(footer: true));
      expect(find.text('Attendance'), findsOneWidget);
      final column = tester.getCenter(
        find.byKey(const ValueKey('heat-column-s1')),
      );
      expect(
        (tester.getCenter(find.text('a1')).dx - column.dx).abs(),
        lessThan(1),
      );
      expect(
        tester.getCenter(find.text('a0')).dy,
        greaterThan(tester.getCenter(find.text('c1-0')).dy),
      );
    });

    testWidgets('grows with the text size instead of cutting the titles', (
      tester,
    ) async {
      await pumpUi(tester, SingleChildScrollView(child: grid()));
      final normal = tester.getSize(find.byKey(const ValueKey('heat-row-t0')));

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpUi(tester, SingleChildScrollView(child: grid()));

      expect(tester.takeException(), isNull);
      final scaled = tester.getSize(find.byKey(const ValueKey('heat-row-t0')));
      expect(scaled.height, greaterThan(normal.height));
    });
  });
}
