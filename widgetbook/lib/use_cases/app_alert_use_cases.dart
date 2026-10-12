import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: AppAlert,
  path: '[Design system]/Composants',
)
Widget buildAppAlertUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: AppAlert(
    level: context.knobs.object.dropdown<AlertLevel>(
      label: 'niveau',
      options: AlertLevel.values,
      labelBuilder: (value) => value.name,
    ),
    message: context.knobs.string(
      label: 'message',
      initialValue: 'Le taux de réussite baisse depuis trois séances.',
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Attention',
  type: AppAlert,
  path: '[Design system]/Composants',
)
Widget buildAppAlertAttentionUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: AppAlert(
    level: AlertLevel.attention,
    message: 'Deux élèves n’ont pas de résultat cette semaine.',
  ),
);

@widgetbook.UseCase(
  name: 'Persistante',
  type: AppAlert,
  path: '[Design system]/Composants',
)
Widget buildAppAlertPersistentUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: AppAlert(
    level: AlertLevel.persistent,
    message: 'Un exercice n’a pas de score saisi.',
  ),
);
