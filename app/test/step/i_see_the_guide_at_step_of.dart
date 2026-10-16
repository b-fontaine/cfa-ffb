import 'package:billard_cfa/shared/ui/step_app_bar.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the guide at step {6} of {10}
///
/// La position de l'étape se lit dans l'en-tête compact (`6/10`) : elle
/// n'est affichée qu'à cet endroit.
Future<void> iSeeTheGuideAtStepOf(
  WidgetTester tester,
  num position,
  num total,
) async {
  expect(
    find.descendant(
      of: find.byType(StepAppBar),
      matching: find.text('${position.toInt()}/${total.toInt()}'),
    ),
    findsOneWidget,
  );
}
