import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseDiagram _diagram(List<TableContact?> contacts) => ExerciseDiagram(
  id: 'd',
  kind: DiagramKind.exercise,
  sheet: 'La puissance',
  exercise: 1,
  caption: 'Légende',
  description: 'Description',
  sourceFile: 'Test.pdf',
  sourcePage: 1,
  table: DiagramTable(
    balls: const [],
    steps: [
      for (final contact in contacts) TableStep(cueId: 'w', contact: contact),
    ],
  ),
);

void main() {
  group('contacts', () {
    test('lists each distinct contact once, in the order of the shots', () {
      final diagram = _diagram(const [
        TableContact.half,
        TableContact.full,
        TableContact.half,
        TableContact.thin,
      ]);

      expect(diagram.contacts, [
        TableContact.half,
        TableContact.full,
        TableContact.thin,
      ]);
    });

    test('ignores the shots without a contact', () {
      final diagram = _diagram(const [null, TableContact.quarter, null]);

      expect(diagram.contacts, [TableContact.quarter]);
    });

    test('is empty when no shot gives a contact', () {
      expect(_diagram(const [null]).contacts, isEmpty);
      expect(_diagram(const []).contacts, isEmpty);
    });
  });
}
