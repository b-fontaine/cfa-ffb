import 'package:billard_cfa/widgets/session_list/presentation/session_list.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the planned session {'Sooner'} is listed before {'Later'}
///
/// Compare la position verticale des deux titres dans la liste des séances
/// planifiées ; chacun doit être unique.
Future<void> thePlannedSessionIsListedBefore(
  WidgetTester tester,
  String first,
  String second,
) async {
  Finder row(String title) =>
      find.descendant(of: find.byType(SessionList), matching: find.text(title));
  expect(row(first), findsOneWidget, reason: 'séance $first ambiguë');
  expect(row(second), findsOneWidget, reason: 'séance $second ambiguë');
  expect(
    tester.getTopLeft(row(first)).dy,
    lessThan(tester.getTopLeft(row(second)).dy),
    reason: 'la séance $first doit précéder $second',
  );
}
