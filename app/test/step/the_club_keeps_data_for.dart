import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the club keeps data for {'Hugo'}
Future<void> theClubKeepsDataFor(WidgetTester tester, String name) async {
  final student = await tester.runAsync(() => UiWorld.studentNamed(name));
  expect(student, isNotNull);
}
