import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/features/suggest_session/presentation/ui/exercise_diagram_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

const _balls = [
  TableBall(
    id: 'y1',
    color: TableBallColor.yellow,
    at: TablePoint(4, 2),
    label: 'x4',
  ),
  TableBall(
    id: 'w',
    color: TableBallColor.white,
    at: TablePoint(4, 3.2),
    role: TableBallRole.cue,
  ),
];

ExerciseDiagram _diagram({
  String id = 'd1',
  List<TableContact?> contacts = const [TableContact.full],
}) => ExerciseDiagram(
  id: id,
  kind: DiagramKind.exercise,
  sheet: 'Bloc b',
  exercise: 2,
  caption: 'Empocher huit billes.',
  description: 'Description',
  sourceFile: 'Test.pdf',
  sourcePage: 3,
  table: DiagramTable(
    balls: _balls,
    steps: [
      for (final contact in contacts)
        TableStep(
          cueId: 'w',
          hitId: 'y1',
          contact: contact,
          pocket: TablePocket.tm,
        ),
    ],
  ),
);

ExerciseSheet _sheet({
  List<ExerciseDiagram> diagrams = const [],
  bool unreadable = false,
}) {
  final b = block('b', 2);
  return ExerciseSheet(
    block: b,
    spec: b.exercises[1],
    diagrams: diagrams,
    diagramsUnreadable: unreadable,
  );
}

Future<void> _show(
  WidgetTester tester,
  ExerciseSheet sheet, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(800, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(child: ExerciseDiagramView(sheet: sheet)),
      ),
    ),
  );
}

void main() {
  testWidgets('plays the diagram of the exercise with its caption', (
    tester,
  ) async {
    await _show(tester, _sheet(diagrams: [_diagram()]));

    expect(find.byType(TableDiagramPlayer), findsOneWidget);
    expect(find.text('Table diagram'), findsOneWidget);
    expect(find.text('Empocher huit billes.'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    final player = tester.widget<TableDiagramPlayer>(
      find.byType(TableDiagramPlayer),
    );
    expect(player.semanticLabel, 'Table diagram of exercise 2, Bloc b');
    expect(player.spec.id, 'd1');
  });

  testWidgets('writes the ball contact in English', (tester) async {
    await _show(tester, _sheet(diagrams: [_diagram()]));

    expect(find.text('Ball contact: Full ball'), findsOneWidget);
  });

  testWidgets('writes the ball contact in French', (tester) async {
    await _show(
      tester,
      _sheet(diagrams: [_diagram()]),
      locale: const Locale('fr'),
    );

    expect(find.text('Schéma de table'), findsOneWidget);
    expect(find.text('Quantité de bille : Bille pleine'), findsOneWidget);
  });

  testWidgets('does not repeat the bridge, which the sheet card gives', (
    tester,
  ) async {
    await _show(tester, _sheet(diagrams: [_diagram()]));

    expect(find.textContaining('Bridge'), findsNothing);
  });

  testWidgets('lists each distinct contact once, in the order of the shots', (
    tester,
  ) async {
    await _show(
      tester,
      _sheet(
        diagrams: [
          _diagram(
            contacts: const [
              TableContact.half,
              TableContact.full,
              TableContact.half,
            ],
          ),
        ],
      ),
    );

    expect(find.text('Ball contact: Half ball, Full ball'), findsOneWidget);
  });

  testWidgets('says when the sheet does not give the ball contact', (
    tester,
  ) async {
    await _show(
      tester,
      _sheet(
        diagrams: [
          _diagram(contacts: const [null]),
        ],
      ),
    );

    expect(
      find.text('Ball contact: not specified on the sheet'),
      findsOneWidget,
    );
  });

  testWidgets('numbers the diagrams when the sheet is printed twice', (
    tester,
  ) async {
    await _show(
      tester,
      _sheet(
        diagrams: [
          _diagram(id: 'a'),
          _diagram(id: 'b'),
        ],
      ),
    );

    expect(find.text('Diagram 1 of 2'), findsOneWidget);
    expect(find.text('Diagram 2 of 2'), findsOneWidget);
    expect(find.byType(TableDiagramPlayer), findsNWidgets(2));
  });

  testWidgets('does not number a single diagram', (tester) async {
    await _show(tester, _sheet(diagrams: [_diagram()]));

    expect(find.textContaining('Diagram 1'), findsNothing);
  });

  testWidgets('says so when the exercise has no diagram', (tester) async {
    await _show(tester, _sheet());

    expect(
      find.text('No diagram is available for this exercise.'),
      findsOneWidget,
    );
    expect(find.byType(TableDiagramPlayer), findsNothing);
  });

  testWidgets('reports unreadable diagrams without a player', (tester) async {
    await _show(tester, _sheet(unreadable: true));

    expect(
      find.text('This exercise diagram is invalid and cannot be displayed.'),
      findsOneWidget,
    );
    expect(
      find.text('No diagram is available for this exercise.'),
      findsNothing,
    );
    expect(find.byType(TableDiagramPlayer), findsNothing);
  });

  for (final (name, size) in [
    ('phone portrait', const Size(360, 780)),
    ('tablet landscape', const Size(1024, 600)),
    ('phone landscape', const Size(780, 360)),
  ]) {
    testWidgets('does not overflow on a $name with text at 200 %', (
      tester,
    ) async {
      await _show(
        tester,
        _sheet(
          diagrams: [
            _diagram(id: 'a'),
            _diagram(id: 'b'),
          ],
        ),
        textScale: 2,
        size: size,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Play'), findsNWidgets(2));
    });
  }
}
