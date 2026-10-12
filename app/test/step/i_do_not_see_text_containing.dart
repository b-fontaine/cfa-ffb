import 'package:flutter_test/flutter_test.dart';

/// Usage: I do not see text containing {'Data is kept in memory only'}
Future<void> iDoNotSeeTextContaining(WidgetTester tester, String text) async {
  expect(find.textContaining(text), findsNothing);
}
