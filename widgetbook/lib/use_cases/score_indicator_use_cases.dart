import 'package:billard_cfa/shared/ui/score_indicator.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: ScoreIndicator,
  path: '[Design system]/Composants',
)
Widget buildScoreIndicatorUseCase(BuildContext context) {
  final total = context.knobs.int.slider(
    label: 'total',
    initialValue: 5,
    min: 1,
    max: 10,
  );
  final score = context.knobs.int.slider(
    label: 'score',
    initialValue: 3,
    max: 10,
  );
  return Center(
    child: ScoreIndicator(score: score.clamp(0, total), total: total),
  );
}

@widgetbook.UseCase(
  name: 'Aucun succès',
  type: ScoreIndicator,
  path: '[Design system]/Composants',
)
Widget buildScoreIndicatorEmptyUseCase(BuildContext context) =>
    const Center(child: ScoreIndicator(score: 0, total: 5));

@widgetbook.UseCase(
  name: 'Tout réussi',
  type: ScoreIndicator,
  path: '[Design system]/Composants',
)
Widget buildScoreIndicatorFullUseCase(BuildContext context) =>
    const Center(child: ScoreIndicator(score: 5, total: 5));
