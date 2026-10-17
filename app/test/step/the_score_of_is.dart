import 'package:flutter_test/flutter_test.dart';

/// Usage: the score of {'Player or team A'} is {3}
///
/// Le score se lit dans l'étiquette d'accessibilité de la colonne
/// (« Player or team A: 3 »).
Future<void> theScoreOfIs(WidgetTester tester, String side, num points) async {
  expect(
    find.bySemanticsLabel('$side: ${points.toInt()}'),
    findsOneWidget,
    reason: 'score de « $side » différent de $points',
  );
}
