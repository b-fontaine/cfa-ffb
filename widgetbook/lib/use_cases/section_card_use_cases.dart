import 'package:billard_cfa/shared/ui/score_indicator.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Texte',
  type: SectionCard,
  path: '[Design system]/Composants',
)
Widget buildSectionCardUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: SectionCard(
    title: context.knobs.string(label: 'titre', initialValue: 'Posture'),
    child: Text(
      context.knobs.string(
        label: 'contenu',
        initialValue: 'Appui stable, regard dans l’axe de la queue.',
      ),
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Avec un score',
  type: SectionCard,
  path: '[Design system]/Composants',
)
Widget buildSectionCardScoreUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: SectionCard(
    title: 'Dernier exercice',
    child: ScoreIndicator(score: 4, total: 6),
  ),
);
