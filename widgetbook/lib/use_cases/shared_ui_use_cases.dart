import 'package:billard_cfa/shared/ui/app_navigation.dart';
import 'package:billard_cfa/shared/ui/cell_grid.dart';
import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/heat_cell.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/nav_icon.dart';
import 'package:billard_cfa/shared/ui/path_cell.dart';
import 'package:billard_cfa/shared/ui/progress_chart.dart';
import 'package:billard_cfa/shared/ui/progress_meter.dart';
import 'package:billard_cfa/shared/ui/scroll_page.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Design system]/Composants';

@widgetbook.UseCase(name: 'Interactif', type: ErrorView, path: _path)
Widget buildErrorViewUseCase(BuildContext context) => ErrorView(
  message: context.knobs.string(
    label: 'message',
    initialValue: 'Impossible de charger les données.',
  ),
  onRetry: () {},
);

@widgetbook.UseCase(name: 'Sans nouvel essai', type: ErrorView, path: _path)
Widget buildErrorViewNoRetryUseCase(BuildContext context) =>
    const ErrorView(message: 'Données illisibles.');

@widgetbook.UseCase(name: 'Chargement', type: LoadingView, path: _path)
Widget buildLoadingViewUseCase(BuildContext context) => const LoadingView();

@widgetbook.UseCase(name: 'Interactif', type: ProgressMeter, path: _path)
Widget buildProgressMeterUseCase(BuildContext context) {
  final maximum = context.knobs.int.slider(
    label: 'maximum',
    initialValue: 5,
    min: 1,
    max: 10,
  );
  final value = context.knobs.int.slider(
    label: 'valeur',
    initialValue: 3,
    max: 10,
  );
  final clamped = value > maximum ? maximum : value;
  return Padding(
    padding: const EdgeInsets.all(16),
    child: ProgressMeter(
      value: clamped,
      maximum: maximum,
      label: '$clamped / $maximum passages réussis',
    ),
  );
}

@widgetbook.UseCase(name: 'Interactif', type: CounterField, path: _path)
Widget buildCounterFieldUseCase(BuildContext context) => _CounterDemo();

class _CounterDemo extends StatefulWidget {
  @override
  State<_CounterDemo> createState() => _CounterDemoState();
}

class _CounterDemoState extends State<_CounterDemo> {
  int _value = 3;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: CounterField(
      label: 'Billes empochées',
      value: _value,
      max: 10,
      onChanged: (next) => setState(() => _value = next),
      decreaseTooltip: 'Une de moins',
      increaseTooltip: 'Une de plus',
    ),
  );
}

@widgetbook.UseCase(name: 'Pas de 10', type: CounterField, path: _path)
Widget buildCounterFieldStepUseCase(BuildContext context) => _StepCounterDemo();

class _StepCounterDemo extends StatefulWidget {
  @override
  State<_StepCounterDemo> createState() => _StepCounterDemoState();
}

class _StepCounterDemoState extends State<_StepCounterDemo> {
  int _value = 50;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: CounterField(
      label: "Part d'échec du groupe (%)",
      value: _value,
      min: 10,
      max: 100,
      step: 10,
      onChanged: (next) => setState(() => _value = next),
      decreaseTooltip: 'Baisser la part',
      increaseTooltip: 'Relever la part',
    ),
  );
}

@widgetbook.UseCase(name: 'Avec retour', type: ScrollPage, path: _path)
Widget buildScrollPageUseCase(BuildContext context) => ScrollPage(
  title: 'Titre de la page',
  subtitle: 'Sous-titre explicatif',
  onBack: () {},
  backLabel: 'Retour',
  children: [
    for (var index = 1; index <= 3; index++)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Section $index'),
        ),
      ),
  ],
);

@widgetbook.UseCase(name: 'Interactif', type: StatusBadge, path: _path)
Widget buildStatusBadgeUseCase(BuildContext context) => Center(
  child: StatusBadge(
    tone: context.knobs.object.dropdown<BadgeTone>(
      label: 'ton',
      options: BadgeTone.values,
      labelBuilder: (value) => value.name,
    ),
    label: context.knobs.string(label: 'libellé', initialValue: 'Validé'),
  ),
);

@widgetbook.UseCase(name: 'Trois tons', type: StatusBadge, path: _path)
Widget buildStatusBadgesUseCase(BuildContext context) => const Center(
  child: Wrap(
    spacing: 12,
    children: [
      StatusBadge(tone: BadgeTone.success, label: 'Validé'),
      StatusBadge(tone: BadgeTone.attention, label: 'À rappeler'),
      StatusBadge(tone: BadgeTone.neutral, label: 'En cours'),
    ],
  ),
);

@widgetbook.UseCase(name: 'Courbe', type: ProgressChart, path: _path)
Widget buildProgressChartUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: ProgressChart(
    points: [
      ChartPoint(value: 2, reached: false),
      ChartPoint(value: 3, reached: false),
      ChartPoint(value: 5, reached: true),
      ChartPoint(value: 4, reached: false),
      ChartPoint(value: 6, reached: true),
    ],
    maxValue: 7,
    target: 5,
    semanticLabel: 'Cinq essais, deux réussis, tendance à la hausse.',
    axisLabelX: 'Essais',
    axisLabelY: 'Billes empochées',
    targetLabel: 'Objectif',
  ),
);

@widgetbook.UseCase(name: 'Vide', type: ProgressChart, path: _path)
Widget buildProgressChartEmptyUseCase(BuildContext context) => const Padding(
  padding: EdgeInsets.all(16),
  child: ProgressChart(
    points: [],
    maxValue: 7,
    target: 5,
    semanticLabel: 'Aucun essai enregistré.',
    axisLabelX: 'Essais',
    axisLabelY: 'Billes empochées',
    targetLabel: 'Objectif',
  ),
);

@widgetbook.UseCase(name: 'Navigation', type: AppNavigation, path: _path)
Widget buildAppNavigationUseCase(BuildContext context) => const _NavDemo();

class _NavDemo extends StatefulWidget {
  const _NavDemo();

  @override
  State<_NavDemo> createState() => _NavDemoState();
}

class _NavDemoState extends State<_NavDemo> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => AppNavigation(
    destinations: const [
      AppDestination(
        icon: NavIcon(NavGlyph.today),
        selectedIcon: NavIcon(NavGlyph.today, selected: true),
        label: 'Accueil',
      ),
      AppDestination(
        icon: NavIcon(NavGlyph.students),
        selectedIcon: NavIcon(NavGlyph.students, selected: true),
        label: 'Élèves',
      ),
      AppDestination(
        icon: NavIcon(NavGlyph.more),
        selectedIcon: NavIcon(NavGlyph.more, selected: true),
        label: 'Sauvegarde',
      ),
    ],
    selectedIndex: _index,
    onSelected: (index) => setState(() => _index = index),
    body: Center(child: Text('Onglet ${_index + 1}')),
  );
}

@widgetbook.UseCase(name: 'Quatre états', type: PathCell, path: _path)
Widget buildPathCellStatesUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    children: [
      PathCell(
        state: PathCellState.todo,
        label: 'Posture · exercice 1 : à faire',
        onTap: () {},
      ),
      PathCell(
        state: PathCellState.started,
        passed: 2,
        label: 'Posture · exercice 2 : commencé, 2 réussites sur 5',
        onTap: () {},
      ),
      PathCell(
        state: PathCellState.validated,
        label: 'Posture · exercice 3 : validé',
        onTap: () {},
      ),
      PathCell(
        state: PathCellState.acquired,
        label: 'Posture · exercice 4 : acquis au positionnement',
        onTap: () {},
      ),
    ],
  ),
);

@widgetbook.UseCase(name: 'Alerte et en cours', type: PathCell, path: _path)
Widget buildPathCellMarkersUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    children: [
      PathCell(
        state: PathCellState.started,
        passed: context.knobs.int.slider(
          label: 'réussites',
          initialValue: 1,
          max: 4,
        ),
        alerted: context.knobs.boolean(label: 'alerte', initialValue: true),
        current: context.knobs.boolean(label: 'en cours', initialValue: true),
        label: 'Posture · exercice 1',
        onTap: () {},
      ),
      const PathCell(
        state: PathCellState.todo,
        current: true,
        label: 'Posture · exercice 2 : à faire, exercice en cours',
      ),
    ],
  ),
);

@widgetbook.UseCase(name: 'Légende', type: PathLegend, path: _path)
Widget buildPathLegendUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: PathLegend(
    exerciseCount: context.knobs.int.slider(
      label: 'exercices',
      initialValue: 70,
      min: 1,
      max: 100,
    ),
  ),
);

@widgetbook.UseCase(name: 'Quatre paliers', type: HeatCell, path: _path)
Widget buildHeatCellLevelsUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    children: [
      HeatCell(
        fraction: '0/4',
        level: HeatLevel.none,
        label: 'Léa, Posture : 0 sur 4 exercices',
        onTap: () {},
      ),
      HeatCell(
        fraction: '1/4',
        level: HeatLevel.some,
        label: 'Léa, Posture : 1 sur 4 exercices',
        onTap: () {},
      ),
      HeatCell(
        fraction: '3/4',
        level: HeatLevel.most,
        label: 'Léa, Posture : 3 sur 4 exercices',
        onTap: () {},
      ),
      HeatCell(
        fraction: '4/4',
        level: HeatLevel.all,
        label: 'Léa, Posture : 4 sur 4 exercices',
        onTap: () {},
      ),
    ],
  ),
);

@widgetbook.UseCase(name: 'Acquis et alerte', type: HeatCell, path: _path)
Widget buildHeatCellMarkersUseCase(BuildContext context) => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    children: [
      HeatCell(
        fraction: '4/4',
        level: HeatLevel.all,
        acquired: true,
        label: 'Léa, Posture : 4 sur 4 exercices, acquis au positionnement',
        onTap: () {},
      ),
      HeatCell(
        fraction: '1/4',
        level: HeatLevel.some,
        alerted: true,
        label: 'Léa, Posture : 1 sur 4 exercices, alerte en cours',
        onTap: () {},
      ),
    ],
  ),
);

@widgetbook.UseCase(name: 'Défilement horizontal', type: CellGrid, path: _path)
Widget buildCellGridUseCase(BuildContext context) {
  final students = context.knobs.int.slider(
    label: 'élèves',
    initialValue: 8,
    min: 1,
    max: 16,
  );
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: CellGrid(
      keyPrefix: 'demo',
      semanticLabel: 'Techniques par élève',
      columns: [
        for (var s = 1; s <= students; s++)
          CellGridColumn(id: 's$s', label: 'Élève $s', onTap: () {}),
      ],
      rows: [
        for (final title in const [
          'Posture, visée et coup de queue',
          'La puissance',
          'Demi-bille',
        ])
          CellGridRow(
            id: title,
            header: title,
            semanticLabel: '$title : résumé',
            cells: [
              for (var s = 1; s <= students; s++)
                HeatCell(
                  fraction: '${s % 5}/4',
                  level: HeatLevel.values[s % 4],
                  label: 'Élève $s, $title',
                  onTap: () {},
                ),
            ],
          ),
      ],
      footer: CellGridRow(
        id: 'presences',
        header: 'Assiduité',
        semanticLabel: 'Assiduité',
        cells: [for (var s = 1; s <= students; s++) Text('${s % 6}/6')],
      ),
    ),
  );
}
