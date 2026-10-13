import 'dart:math' as math;

import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:billard_cfa/shared/ui/billiard_table.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: BilliardCue,
  path: '[Design system]/Composants',
)
Widget buildBilliardCueUseCase(BuildContext context) {
  final length = context.knobs.double.slider(
    label: 'longueur',
    initialValue: 360,
    min: 120,
    max: 600,
  );
  final thickness = context.knobs.double.slider(
    label: 'épaisseur',
    initialValue: 16,
    min: 6,
    max: 32,
  );
  final angle = context.knobs.double.slider(
    label: 'angle (rad)',
    min: -math.pi,
    max: math.pi,
  );
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(48),
      child: BilliardCue(length: length, thickness: thickness, angle: angle),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Seule',
  type: BilliardCue,
  path: '[Design system]/Composants',
)
Widget buildBilliardCueAloneUseCase(BuildContext context) => const Center(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: BilliardCue(length: 360, thickness: 16),
  ),
);

@widgetbook.UseCase(
  name: "Pointe contre la blanche (queue de 1450 mm à l'échelle)",
  type: BilliardCue,
  path: '[Design system]/Composants',
)
Widget buildBilliardCueOnTableUseCase(BuildContext context) {
  final angle = context.knobs.double.slider(
    label: 'angle (rad)',
    initialValue: math.pi,
    min: -math.pi,
    max: math.pi,
  );
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Center(
      child: BilliardTable(
        showGrid: true,
        overlay: (context, geometry) => Stack(
          children: [
            BilliardCue.positionedAgainst(
              geometry: geometry,
              ball: const Offset(6, 2),
              angle: angle,
            ),
            Positioned.fromRect(
              rect: geometry.ballRect(const Offset(6, 2), BallKind.white),
              child: BilliardBall(kind: BallKind.white, geometry: geometry),
            ),
          ],
        ),
      ),
    ),
  );
}
