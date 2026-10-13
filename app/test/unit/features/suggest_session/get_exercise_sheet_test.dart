import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/features/suggest_session/domain/get_exercise_sheet.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';
import '../../../support/fixtures.dart';

class _FixedDiagrams implements DiagramRepository {
  _FixedDiagrams(this.diagrams);

  final List<ExerciseDiagram> diagrams;

  @override
  Future<DiagramLibrary> load() async => DiagramLibrary(diagrams);
}

class _FailingDiagrams implements DiagramRepository {
  _FailingDiagrams(this.failure);

  final Failure failure;

  @override
  Future<DiagramLibrary> load() async => throw failure;
}

class _UnreadableDiagrams implements DiagramRepository {
  @override
  Future<DiagramLibrary> load() async =>
      throw const InvariantViolation(InvariantCode.invalidDiagram);
}

ExerciseDiagram _diagram(
  String id, {
  required String sheet,
  int? exercise,
  DiagramKind kind = DiagramKind.exercise,
}) => ExerciseDiagram(
  id: id,
  kind: kind,
  sheet: sheet,
  exercise: exercise,
  caption: 'Légende',
  description: 'Description',
  sourceFile: 'Test.pdf',
  sourcePage: 1,
  table: const DiagramTable(balls: []),
);

void main() {
  late GetExerciseSheet getSheet;

  GetExerciseSheet sheetWith(List<ExerciseDiagram> diagrams) =>
      GetExerciseSheet(
        DomainWorld().catalogueRepository,
        _FixedDiagrams(diagrams),
      );

  setUp(() {
    getSheet = sheetWith(const []);
  });

  test('gives the exercise with its block', () async {
    final sheet = ok(await getSheet(ref('b', 2)));

    expect(sheet.block.id, 'b');
    expect(sheet.block.title, 'Bloc b');
    expect(sheet.spec.ref, ref('b', 2));
    expect(sheet.spec.rate, rate());
  });

  test('refuses an unknown exercise', () async {
    final result = await getSheet(ref('b', 9));

    expect(codeOf(result), InvariantCode.unknownExercise);
  });

  test('refuses an unknown block', () async {
    final result = await getSheet(ref('zzz', 1));

    expect(codeOf(result), InvariantCode.unknownExercise);
  });

  test(
    'gives the diagrams whose sheet title and number match, in order',
    () async {
      final sheet = ok(
        await sheetWith([
          _diagram('first', sheet: 'Bloc b', exercise: 2),
          _diagram('other-number', sheet: 'Bloc b', exercise: 1),
          _diagram('other-title', sheet: 'Bloc a', exercise: 2),
          _diagram(
            'other-kind',
            sheet: 'Bloc b',
            exercise: 2,
            kind: DiagramKind.game,
          ),
          _diagram('second', sheet: 'Bloc b', exercise: 2),
        ])(ref('b', 2)),
      );

      expect(sheet.diagrams.map((d) => d.id), ['first', 'second']);
      expect(sheet.diagramsUnreadable, isFalse);
    },
  );

  test('has no diagram when the library has none for the exercise', () async {
    final sheet = ok(await getSheet(ref('b', 2)));

    expect(sheet.diagrams, isEmpty);
    expect(sheet.diagramsUnreadable, isFalse);
  });

  test(
    'keeps the sheet and flags the diagrams when they cannot be read',
    () async {
      final sheet = ok(
        await GetExerciseSheet(
          DomainWorld().catalogueRepository,
          _UnreadableDiagrams(),
        )(ref('b', 2)),
      );

      expect(sheet.spec.ref, ref('b', 2));
      expect(sheet.diagrams, isEmpty);
      expect(sheet.diagramsUnreadable, isTrue);
    },
  );

  test('lets any other invariant violation fail the sheet', () async {
    final result = await GetExerciseSheet(
      DomainWorld().catalogueRepository,
      _FailingDiagrams(
        const InvariantViolation(InvariantCode.successRateOutOfRange),
      ),
    )(ref('b', 2));

    expect(codeOf(result), InvariantCode.successRateOutOfRange);
  });
}
