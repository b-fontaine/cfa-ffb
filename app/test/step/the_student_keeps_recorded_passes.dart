import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the student {'Hugo'} keeps {2} recorded passes
Future<void> theStudentKeepsRecordedPasses(
  WidgetTester tester,
  String name,
  num count,
) async {
  expect(await UiWorld.attemptCountOf(name), count.toInt());
}
