import 'package:flutter_test/flutter_test.dart';

/// Usage: I see {'Proposal'} text {2} times
Future<void> iSeeTextTimes(WidgetTester tester, String text, int count) async {
  expect(find.text(text), findsNWidgets(count));
}
