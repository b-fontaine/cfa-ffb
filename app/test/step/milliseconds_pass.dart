import 'package:flutter_test/flutter_test.dart';

/// Usage: {100} milliseconds pass
Future<void> millisecondsPass(WidgetTester tester, num milliseconds) async {
  await tester.pump(Duration(milliseconds: milliseconds.toInt()));
}
