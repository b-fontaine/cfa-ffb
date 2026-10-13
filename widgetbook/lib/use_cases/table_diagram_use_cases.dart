import 'package:billard_cfa/shared/ui/table_diagram/table_diagram.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/diagram_examples.dart';

DiagramExample _example(BuildContext context) =>
    context.knobs.object.dropdown<DiagramExample>(
      label: 'exercice',
      options: diagramExamples,
      labelBuilder: (value) => value.name,
    );

double _width(BuildContext context, {double initial = 480}) => context
    .knobs
    .double
    .slider(label: 'largeur', initialValue: initial, min: 200, max: 640);

Widget _page(double width, Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: width, child: child),
  ),
);

@widgetbook.UseCase(
  name: 'Statique (interactif)',
  type: TableDiagram,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramUseCase(BuildContext context) {
  final example = _example(context);
  return _page(
    _width(context),
    TableDiagram(
      spec: example.spec,
      semanticLabel: example.description,
      showGrid: context.knobs.boolean(label: 'grille', initialValue: true),
      showHeadString: context.knobs.boolean(
        label: 'ligne de départ',
        initialValue: true,
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Statique, jeu avec zones',
  type: TableDiagram,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramGameUseCase(BuildContext context) => _page(
  _width(context),
  TableDiagram(spec: powerGame.spec, semanticLabel: powerGame.description),
);

@widgetbook.UseCase(
  name: 'Statique, largeur réduite',
  type: TableDiagram,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramNarrowUseCase(BuildContext context) => _page(
  _width(context, initial: 240),
  TableDiagram(spec: fullBall.spec, semanticLabel: fullBall.description),
);

@widgetbook.UseCase(
  name: 'Statique, table vide',
  type: TableDiagram,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramEmptyUseCase(BuildContext context) => _page(
  _width(context),
  const TableDiagram(
    spec: TableDiagramSpec(id: 'vide', balls: []),
    semanticLabel: 'Table vide',
  ),
);

@widgetbook.UseCase(
  name: "Schéma invalide (état d'erreur)",
  type: TableDiagram,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramInvalidUseCase(BuildContext context) => _page(
  _width(context),
  const TableDiagram(
    spec: TableDiagramSpec(
      id: 'invalide',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(9, 1)),
      ],
    ),
    semanticLabel: 'Schéma invalide',
  ),
);

@widgetbook.UseCase(
  name: "Lecteur, schéma invalide (état d'erreur)",
  type: TableDiagramPlayer,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramPlayerInvalidUseCase(BuildContext context) => _page(
  _width(context),
  const TableDiagramPlayer(
    spec: TableDiagramSpec(
      id: 'invalide',
      balls: [
        DiagramBall(id: 'w', color: BallKind.white, at: DiagramPoint(9, 1)),
      ],
    ),
    semanticLabel: 'Schéma invalide',
  ),
);

@widgetbook.UseCase(
  name: 'Animé (interactif)',
  type: TableDiagramPlayer,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramPlayerUseCase(BuildContext context) {
  final example = _example(context);
  return _page(
    _width(context),
    TableDiagramPlayer(
      // Une nouvelle clé par exercice : le joueur repart de zéro.
      key: ValueKey(example.spec.id),
      spec: example.spec,
      semanticLabel: example.description,
      showGrid: context.knobs.boolean(label: 'grille', initialValue: true),
      showHeadString: context.knobs.boolean(
        label: 'ligne de départ',
        initialValue: true,
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Animé, bille pleine',
  type: TableDiagramPlayer,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramPlayerFullBallUseCase(BuildContext context) => _page(
  _width(context),
  TableDiagramPlayer(spec: fullBall.spec, semanticLabel: fullBall.description),
);

@widgetbook.UseCase(
  name: 'Animé, demi-bille',
  type: TableDiagramPlayer,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramPlayerHalfBallUseCase(BuildContext context) => _page(
  _width(context),
  TableDiagramPlayer(spec: halfBall.spec, semanticLabel: halfBall.description),
);

@widgetbook.UseCase(
  name: 'Animé, rebonds sur deux bandes',
  type: TableDiagramPlayer,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramPlayerBanksUseCase(BuildContext context) => _page(
  _width(context),
  TableDiagramPlayer(
    spec: twoCushions.spec,
    semanticLabel: twoCushions.description,
  ),
);

@widgetbook.UseCase(
  name: 'Animé, jeu sans tir (schéma seul)',
  type: TableDiagramPlayer,
  path: '[Design system]/Composants',
)
Widget buildTableDiagramPlayerStaticUseCase(BuildContext context) => _page(
  _width(context),
  TableDiagramPlayer(
    spec: powerGame.spec,
    semanticLabel: powerGame.description,
  ),
);
