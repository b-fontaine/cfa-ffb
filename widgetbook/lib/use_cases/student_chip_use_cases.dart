import 'package:billard_cfa/shared/ui/student_chip.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Design system]/Composants';

@widgetbook.UseCase(name: 'Interactif', type: StudentChip, path: _path)
Widget buildStudentChipUseCase(BuildContext context) {
  final status = context.knobs.object.dropdown<StudentChipStatus>(
    label: 'état',
    options: StudentChipStatus.values,
    initialOption: StudentChipStatus.todo,
    labelBuilder: (value) => value.name,
  );
  final name = context.knobs.string(label: 'prénom', initialValue: 'Zoé');
  return Padding(
    padding: const EdgeInsets.all(16),
    child: StudentChip(
      name: name,
      detail: '2/5',
      status: status,
      statusLabel: status.name,
    ),
  );
}

@widgetbook.UseCase(name: 'Trois états', type: StudentChip, path: _path)
Widget buildStudentChipStatesUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    children: [
      StudentChip(
        name: 'Zoé',
        detail: '0/5',
        status: StudentChipStatus.todo,
        statusLabel: 'à faire',
      ),
      StudentChip(
        name: 'Abel',
        detail: '1/5',
        status: StudentChipStatus.missed,
        statusLabel: 'manqué',
      ),
      StudentChip(
        name: 'Léa',
        detail: '3/5',
        status: StudentChipStatus.reached,
        statusLabel: 'réussi',
      ),
    ],
  ),
);

@widgetbook.UseCase(name: 'Prénom long', type: StudentChip, path: _path)
Widget buildStudentChipLongNameUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: StudentChip(
    name: 'Marie-Charlotte de la Fontaine-Beauregard',
    status: StudentChipStatus.todo,
    statusLabel: 'à faire',
    maxWidth: 140,
  ),
);
