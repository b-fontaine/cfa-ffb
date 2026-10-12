import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: BallChip,
  path: '[Design system]/Composants',
)
Widget buildBallChipUseCase(BuildContext context) {
  final kind = context.knobs.object.dropdown<BallKind>(
    label: 'bille',
    options: BallKind.values,
    labelBuilder: (value) => value.name,
  );
  final size = context.knobs.double.slider(
    label: 'taille',
    initialValue: 40,
    min: 24,
    max: 96,
  );
  return Center(
    child: BallChip(kind: kind, size: size),
  );
}

@widgetbook.UseCase(
  name: 'Les quatre groupes',
  type: BallChip,
  path: '[Design system]/Composants',
)
Widget buildBallChipGroupsUseCase(BuildContext context) => Center(
  child: Wrap(
    spacing: 12,
    children: [for (final kind in BallKind.values) BallChip(kind: kind)],
  ),
);
