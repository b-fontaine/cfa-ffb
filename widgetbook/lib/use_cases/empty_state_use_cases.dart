import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: EmptyState,
  path: '[Design system]/Composants',
)
Widget buildEmptyStateUseCase(BuildContext context) => EmptyState(
  message: context.knobs.string(
    label: 'message',
    initialValue: 'Aucun élève pour le moment.',
  ),
);

@widgetbook.UseCase(
  name: 'Avec une action',
  type: EmptyState,
  path: '[Design system]/Composants',
)
Widget buildEmptyStateActionUseCase(BuildContext context) => EmptyState(
  message: 'Aucune séance planifiée pour le moment.',
  icon: Icons.event_busy_outlined,
  action: FilledButton(onPressed: () {}, child: const Text('Planifier')),
);
