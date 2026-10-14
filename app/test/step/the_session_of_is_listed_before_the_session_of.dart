import 'package:billard_cfa/features/record_results/presentation/ui/recorded_session_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session of {'Sep 13'} is listed before the session of {'Sep 12'}
///
/// Compare la position verticale des deux lignes de l'historique ; chacune
/// doit être unique.
Future<void> theSessionOfIsListedBeforeTheSessionOf(
  WidgetTester tester,
  String first,
  String second,
) async {
  Finder row(String date) => find.descendant(
    of: find.byType(RecordedSessionList),
    matching: find.textContaining(date),
  );
  expect(row(first), findsOneWidget, reason: 'séance du $first ambiguë');
  expect(row(second), findsOneWidget, reason: 'séance du $second ambiguë');
  expect(
    tester.getTopLeft(row(first)).dy,
    lessThan(tester.getTopLeft(row(second)).dy),
    reason: 'la séance du $first doit précéder celle du $second',
  );
}
