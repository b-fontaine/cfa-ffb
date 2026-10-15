import 'package:billard_cfa/shared/ui/app_tabs.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(
  name: 'Séances',
  type: AppTabs,
  path: '[Design system]/Composants',
)
Widget buildAppTabsUseCase(BuildContext context) => AppTabs(
  labels: const ['Planifiées', 'Catalogue', 'Suggestion'],
  selectedIndex: context.knobs.int.slider(
    label: 'onglet',
    initialValue: 1,
    max: 2,
  ),
  onSelected: (_) {},
);
