import 'package:billard_cfa/shared/ui/archive_figure_table.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  const rows = <ArchiveFigureRow>[
    (
      title: 'Posture',
      number: 1,
      students: 3,
      attempts: 6,
      potted: 9,
      total: 18,
    ),
    (
      title: 'La puissance',
      number: 2,
      students: 4,
      attempts: 5,
      potted: 7,
      total: 25,
    ),
  ];

  testWidgets('shows a header and one line per exercise', (tester) async {
    await pumpUi(tester, const ArchiveFigureTable(rows: rows));

    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Passes'), findsOneWidget);
    expect(find.text('Balls'), findsOneWidget);
    expect(find.text('Posture · 1'), findsOneWidget);
    expect(find.text('9 of 18'), findsOneWidget);
    expect(find.text('La puissance · 2'), findsOneWidget);
    expect(find.text('7 of 25'), findsOneWidget);
  });

  testWidgets('reads each line as one sentence', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpUi(tester, const ArchiveFigureTable(rows: rows));

    expect(
      find.bySemanticsLabel(
        'Posture, exercise 1: 3 students, 6 passes, 9 of 18 balls',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('draws only the header without any line', (tester) async {
    await pumpUi(tester, const ArchiveFigureTable(rows: []));

    expect(find.text('Exercise'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });
}
