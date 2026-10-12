import 'package:flutter_test/flutter_test.dart';

/// Usage: I see text containing {'Data is kept in memory only'}
Future<void> iSeeTextContaining(WidgetTester tester, String text) async {
  expect(find.textContaining(text), findsOneWidget);
}
