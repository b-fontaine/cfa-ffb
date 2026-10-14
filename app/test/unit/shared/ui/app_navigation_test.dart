import 'package:billard_cfa/shared/ui/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

final _destinations = [
  AppDestination.material(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
  ),
  AppDestination.material(
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    label: 'Students',
  ),
];

Widget _navigation({int selected = 0, ValueChanged<int>? onSelected}) =>
    AppNavigation(
      destinations: _destinations,
      selectedIndex: selected,
      onSelected: onSelected ?? (_) {},
      body: const Text('body'),
    );

void main() {
  testWidgets('uses a bottom bar on a phone', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpUi(tester, _navigation());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('uses a rail on a tablet', (tester) async {
    tester.view
      ..physicalSize = const Size(1000, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpUi(tester, _navigation());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('switches exactly at the breakpoint', (tester) async {
    tester.view
      ..physicalSize = const Size(720, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpUi(tester, _navigation());
    expect(find.byType(NavigationRail), findsOneWidget);

    tester.view.physicalSize = const Size(719, 800);
    await tester.pump();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('always shows the labels and reports the selection', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? selected;

    await pumpUi(tester, _navigation(onSelected: (i) => selected = i));
    await tester.tap(find.text('Students'));

    expect(find.text('Home'), findsOneWidget);
    expect(selected, 1);
  });

  testWidgets('marks the selected destination on the rail', (tester) async {
    tester.view
      ..physicalSize = const Size(1000, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpUi(tester, _navigation(selected: 1));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 1);
  });

  testWidgets('keeps a custom breakpoint', (tester) async {
    tester.view
      ..physicalSize = const Size(500, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpUi(
      tester,
      AppNavigation(
        destinations: _destinations,
        selectedIndex: 0,
        onSelected: (_) {},
        body: const Text('body'),
        wideBreakpoint: 400,
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
