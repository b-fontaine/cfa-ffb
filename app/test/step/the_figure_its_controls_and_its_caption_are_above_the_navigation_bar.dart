import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the figure, its controls and its caption are above the navigation bar
Future<void> theFigureItsControlsAndItsCaptionAreAboveTheNavigationBar(
  WidgetTester tester,
) async {
  final scope = find.byType(PresentationScope);
  // Sans figure à montrer, rien à vérifier : le scénario doit en avoir une.
  expect(scope, findsWidgets);
  final bar = tester.getRect(
    find.ancestor(
      of: find.byIcon(Icons.chevron_left),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );
  for (final element in scope.evaluate()) {
    final rect = tester.getRect(find.byElementPredicate((e) => e == element));
    expect(
      rect.bottom,
      lessThanOrEqualTo(bar.top + 0.5),
      reason: 'la figure, ses commandes et sa légende passent sous la barre',
    );
  }
}
