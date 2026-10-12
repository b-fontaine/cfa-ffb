import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the session of the group {'Children group'}
Future<void> iOpenTheSessionOfTheGroup(
  WidgetTester tester,
  String group,
) async {
  await tester.tap(find.text('Results'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(group));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open the session'));
  await tester.pumpAndSettle();
}
