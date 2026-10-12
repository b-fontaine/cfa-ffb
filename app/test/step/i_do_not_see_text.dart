import 'package:flutter_test/flutter_test.dart';

/// Usage: I do not see {'text'} text
Future<void> iDoNotSeeText(WidgetTester tester, String text) async {
  expect(find.text(text), findsNothing);
}
