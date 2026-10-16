import 'package:billard_cfa/shared/ui/step_app_bar.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the guide at step {6}
///
/// Comme `I see the guide at step {6} of {10}`, sans fixer le nombre total
/// d'étapes (utile pour jalonner un enchaînement de « Suivant »).
Future<void> iSeeTheGuideAtStep(WidgetTester tester, num position) async {
  expect(
    find.descendant(
      of: find.byType(StepAppBar),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            RegExp('^${position.toInt()}/\\d+\$').hasMatch(widget.data ?? ''),
      ),
    ),
    findsOneWidget,
  );
}
