import 'package:billard_cfa/shared/ui/step_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Design system]/Composants';

final _actions = [
  StepAppBarAction(label: 'Sommaire', icon: Icons.list, onSelected: () {}),
  StepAppBarAction(label: 'Mode relecture', checked: true, onSelected: () {}),
  StepAppBarAction(
    label: 'Minuteur à zéro',
    icon: Icons.restart_alt,
    enabled: false,
    onSelected: () {},
  ),
  StepAppBarAction(
    label: 'Terminer la séance',
    icon: Icons.flag,
    onSelected: () {},
  ),
];

@widgetbook.UseCase(name: 'Interactif', type: StepAppBar, path: _path)
Widget buildStepAppBarUseCase(BuildContext context) {
  final total = context.knobs.int.slider(
    label: 'nombre d’étapes',
    initialValue: 9,
    min: 1,
    max: 12,
  );
  final position = context.knobs.int.slider(
    label: 'position',
    initialValue: 6,
    min: 1,
    max: 12,
  );
  return Scaffold(
    appBar: StepAppBar(
      title: context.knobs.string(label: 'titre', initialValue: 'Entraînement'),
      position: position.clamp(1, total),
      total: total,
      onBack: () {},
      actions: _actions,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Bouton fermer, sans menu',
  type: StepAppBar,
  path: _path,
)
Widget buildStepAppBarCloseUseCase(BuildContext context) => Scaffold(
  appBar: StepAppBar(
    title: 'Bilan de la séance',
    position: 9,
    total: 9,
    onClose: () {},
  ),
);

@widgetbook.UseCase(name: 'Titre long', type: StepAppBar, path: _path)
Widget buildStepAppBarLongUseCase(BuildContext context) => Scaffold(
  appBar: StepAppBar(
    title: 'Entraînement approfondi des trajectoires complexes à la bande',
    position: 12,
    total: 12,
    onBack: () {},
    actions: _actions,
  ),
);
