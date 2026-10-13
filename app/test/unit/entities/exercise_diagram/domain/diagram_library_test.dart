import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseDiagram _diagram(
  String id, {
  DiagramKind kind = DiagramKind.exercise,
  String sheet = 'La puissance',
  int? exercise,
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
  final library = DiagramLibrary([
    _diagram('a', exercise: 1),
    _diagram('b', exercise: 2),
    _diagram('c', exercise: 2),
    _diagram('d', kind: DiagramKind.initiation, exercise: 1),
    _diagram('e', kind: DiagramKind.game),
  ]);

  test('finds a diagram by id', () {
    expect(library.byId('b')!.exercise, 2);
  });

  test('has no diagram for an unknown id', () {
    expect(library.byId('zz'), isNull);
  });

  test('finds the diagrams of a key, in order', () {
    final found = library.find(
      DiagramKey.training(sheet: 'La puissance', exercise: 2),
    );

    expect(found.map((d) => d.id), ['b', 'c']);
  });

  test('does not mix the families of fiches under the same title', () {
    final found = library.find(
      const DiagramKey(
        kind: DiagramKind.initiation,
        sheet: 'La puissance',
        exercise: 1,
      ),
    );

    expect(found.map((d) => d.id), ['d']);
  });

  test('finds the diagrams that carry no exercise number', () {
    final found = library.find(
      const DiagramKey(kind: DiagramKind.game, sheet: 'La puissance'),
    );

    expect(found.map((d) => d.id), ['e']);
  });

  test('finds nothing for an exercise the source does not illustrate', () {
    expect(
      library.find(DiagramKey.training(sheet: 'La puissance', exercise: 9)),
      isEmpty,
    );
  });

  test('rejects duplicated ids', () {
    expect(
      () => DiagramLibrary([_diagram('a'), _diagram('a')]),
      throwsA(
        isA<InvariantViolation>().having(
          (e) => e.code,
          'code',
          InvariantCode.invalidDiagram,
        ),
      ),
    );
  });

  test('a diagram knows its key', () {
    expect(
      _diagram('a', exercise: 3).key,
      DiagramKey.training(sheet: 'La puissance', exercise: 3),
    );
  });
}
