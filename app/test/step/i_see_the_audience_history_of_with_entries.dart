import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the audience history of {'Hugo'} with {2} entries
Future<void> iSeeTheAudienceHistoryOfWithEntries(
  WidgetTester tester,
  String name,
  num count,
) async {
  expect(find.textContaining(' since '), findsNWidgets(count.toInt()));
}
