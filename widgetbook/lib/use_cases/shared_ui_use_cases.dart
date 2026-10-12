import 'package:billard_cfa/shared/ui/app_navigation.dart';
import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
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
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Accueil',
      ),
      AppDestination(
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: 'Élèves',
      ),
      AppDestination(
        icon: Icons.save_alt_outlined,
        selectedIcon: Icons.save_alt,
        label: 'Sauvegarde',
      ),
    ],
    selectedIndex: _index,
    onSelected: (index) => setState(() => _index = index),
    body: Center(child: Text('Onglet ${_index + 1}')),
  );
}
