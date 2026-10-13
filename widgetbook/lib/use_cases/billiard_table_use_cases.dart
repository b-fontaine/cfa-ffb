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
  type: BilliardTable,
  path: '[Design system]/Composants',
)
Widget buildBilliardTableUseCase(BuildContext context) {
  final showGrid = context.knobs.boolean(
    label: 'grille 8 × 4',
    initialValue: true,
  );
  final showHeadString = context.knobs.boolean(
    label: 'ligne de départ',
    initialValue: true,
  );
  final withCue = context.knobs.boolean(label: 'queue', initialValue: true);
  final angle = context.knobs.double.slider(
    label: 'angle de la queue (rad)',
    initialValue: -math.pi / 3,
    min: -math.pi,
    max: math.pi,
  );
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Center(
      child: BilliardTable(
        showGrid: showGrid,
        showHeadString: showHeadString,
        overlay: (context, geometry) => Stack(
          children: [
            Positioned.fromRect(
              rect: geometry.ballRect(const Offset(1.4, 1.5)),
              child: BilliardBall(
                kind: BallKind.yellow,
                geometry: geometry,
                label: '1',
              ),
            ),
            Positioned.fromRect(
              rect: geometry.ballRect(const Offset(3, 1.2)),
              child: BilliardBall(kind: BallKind.red, geometry: geometry),
            ),
            if (withCue)
              BilliardCue.positionedAgainst(
                geometry: geometry,
                ball: const Offset(5, 3),
                angle: angle,
              ),
            Positioned.fromRect(
              rect: geometry.ballRect(const Offset(5, 3)),
              child: BilliardBall(kind: BallKind.white, geometry: geometry),
            ),
          ],
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Table vide',
  type: BilliardTable,
  path: '[Design system]/Composants',
)
Widget buildBilliardTableEmptyUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: Center(child: BilliardTable()),
);

@widgetbook.UseCase(
  name: 'Grille et ligne de départ',
  type: BilliardTable,
  path: '[Design system]/Composants',
)
Widget buildBilliardTableGridUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: Center(child: BilliardTable(showGrid: true, showHeadString: true)),
);

@widgetbook.UseCase(
  name: 'Les quatre groupes de billes',
  type: BilliardTable,
  path: '[Design system]/Composants',
)
Widget buildBilliardTableBallsUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Center(
    child: BilliardTable(
      showGrid: true,
      showHeadString: true,
      overlay: (context, geometry) => Stack(
        children: [
          for (final (index, kind) in BallKind.values.indexed)
            Positioned.fromRect(
              rect: geometry.ballRect(Offset(1.5 + index * 1.5, 2)),
              child: BilliardBall(kind: kind, geometry: geometry),
            ),
        ],
      ),
    ),
  ),
);
