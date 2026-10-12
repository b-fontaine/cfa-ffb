import 'package:billard_cfa/features/assess_maturity/presentation/ui/score_selector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I give {4} for the criterion {'Concentration'}
Future<void> iGiveForTheCriterion(
  WidgetTester tester,
  num score,
  String criterion,
) async {
  final selector = find.ancestor(
    of: find.text(criterion),
    matching: find.byType(ScoreSelector),
  );
  final choice = find.descendant(
    of: selector,
    matching: find.text('${score.toInt()}'),
  );
  await tester.ensureVisible(choice);
  await tester.tap(choice);
  await tester.pumpAndSettle();
}
