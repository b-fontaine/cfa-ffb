import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the student {'Hugo'} belongs to the group {'Wednesday'}
Future<void> theStudentBelongsToTheGroup(
  WidgetTester tester,
  String student,
  String group,
) async {
  final name = await tester.runAsync(() => UiWorld.groupNameOf(student));
  expect(name, group);
}
