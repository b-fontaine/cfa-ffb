import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Libellés et index sélectionné de la navigation principale affichée (barre
/// ou rail).
({List<String> labels, int selected}) readMainNavigation(WidgetTester tester) {
  final bar = find.byType(NavigationBar);
  if (bar.evaluate().isNotEmpty) {
    final widget = tester.widget<NavigationBar>(bar);
    return (
      labels: [
        for (final d in widget.destinations)
          if (d is NavigationDestination) d.label,
      ],
      selected: widget.selectedIndex,
    );
  }
  final widget = tester.widget<NavigationRail>(find.byType(NavigationRail));
  return (
    labels: [for (final d in widget.destinations) (d.label as Text).data ?? ''],
    selected: widget.selectedIndex ?? -1,
  );
}
