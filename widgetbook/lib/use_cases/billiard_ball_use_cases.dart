import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/ball_size_comparison.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: BilliardBall,
  path: '[Design system]/Composants',
)
Widget buildBilliardBallUseCase(BuildContext context) {
  final kind = context.knobs.object.dropdown<BallKind>(
    label: 'bille',
    options: BallKind.values,
    labelBuilder: (value) => value.name,
  );
  final diameter = context.knobs.double.slider(
    label: 'diamètre',
    initialValue: 64,
    min: 8,
    max: 128,
  );
  final label = context.knobs.string(label: 'libellé');
  final showLetter = context.knobs.boolean(label: 'lettre', initialValue: true);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: BilliardBall(
        kind: kind,
        diameter: diameter,
        label: label.isEmpty ? null : label,
        showLetter: showLetter,
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Les quatre groupes',
  type: BilliardBall,
  path: '[Design system]/Composants',
)
Widget buildBilliardBallGroupsUseCase(BuildContext context) => Center(
  child: Wrap(
    spacing: 16,
    children: [
      for (final kind in BallKind.values)
        BilliardBall(kind: kind, diameter: 64),
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Numérotées',
  type: BilliardBall,
  path: '[Design system]/Composants',
)
Widget buildBilliardBallNumberedUseCase(BuildContext context) => Center(
  child: Wrap(
    spacing: 16,
    children: [
      for (final (index, kind) in BallKind.values.indexed)
        BilliardBall(kind: kind, diameter: 56, label: '${index + 1}'),
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Taille de la table (libellé à côté)',
  type: BilliardBall,
  path: '[Design system]/Composants',
)
Widget buildBilliardBallSmallUseCase(BuildContext context) => const Center(
  child: Padding(
    padding: EdgeInsets.all(32),
    child: BilliardBall(kind: BallKind.yellow, diameter: 10, label: '3'),
  ),
);

@widgetbook.UseCase(
  name: 'Comparaison de tailles (blanche 48,0 mm, bille de but 50,8 mm)',
  type: BallSizeComparison,
  path: '[Design system]/Composants',
)
Widget buildBallSizeComparisonUseCase(BuildContext context) => Center(
  child: Padding(
    padding: const EdgeInsets.all(32),
    child: BallSizeComparison(
      objectDiameter: context.knobs.double.slider(
        label: 'diamètre de la bille de but',
        initialValue: 160,
        min: 48,
        max: 320,
      ),
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Comparaison de tailles (largeur réduite)',
  type: BallSizeComparison,
  path: '[Design system]/Composants',
)
Widget buildBallSizeComparisonNarrowUseCase(BuildContext context) =>
    const Center(
      child: SizedBox(
        width: 240,
        child: BallSizeComparison(objectDiameter: 72),
      ),
    );
