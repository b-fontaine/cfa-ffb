import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Interactif',
  type: BallContactDiagram,
  path: '[Design system]/Composants',
)
Widget buildBallContactDiagramUseCase(BuildContext context) => Center(
  child: SizedBox(
    width: context.knobs.double.slider(
      label: 'largeur',
      initialValue: 320,
      min: 160,
      max: 480,
    ),
    child: BallContactDiagram(
      contact: context.knobs.object.dropdown<ContactFraction>(
        label: 'quantité de bille',
        options: ContactFraction.values,
        labelBuilder: (value) => value.name,
      ),
      tipPoint: context.knobs.object.dropdown<TipPoint>(
        label: 'point du procédé',
        options: TipPoint.values,
        labelBuilder: (value) => value.name,
      ),
      target: context.knobs.object.dropdown<BallKind>(
        label: 'bille cible',
        options: const [BallKind.red, BallKind.yellow, BallKind.black],
        labelBuilder: (value) => value.name,
      ),
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Les cinq quantités',
  type: BallContactDiagram,
  path: '[Design system]/Composants',
)
Widget buildBallContactDiagramAllUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      for (final contact in ContactFraction.values)
        SizedBox(width: 240, child: BallContactDiagram(contact: contact)),
    ],
  ),
);

@widgetbook.UseCase(
  name: 'Points du procédé',
  type: BallContactDiagram,
  path: '[Design system]/Composants',
)
Widget buildBallContactDiagramTipUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 16,
    runSpacing: 16,
    children: [
      for (final tip in TipPoint.values)
        SizedBox(
          width: 240,
          child: BallContactDiagram(
            contact: ContactFraction.half,
            tipPoint: tip,
          ),
        ),
    ],
  ),
);
