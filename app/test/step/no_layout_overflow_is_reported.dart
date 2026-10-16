import 'package:flutter_test/flutter_test.dart';

/// Usage: no layout overflow is reported
Future<void> noLayoutOverflowIsReported(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
}
