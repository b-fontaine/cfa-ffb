import 'package:flutter_test/flutter_test.dart';

import '../support/local_data_world.dart';

/// Usage: the saved local file holds {6} students and {72} passes
Future<void> theSavedLocalFileHoldsStudentsAndPasses(
  WidgetTester tester,
  num students,
  num passes,
) async {
  final file = LocalDataWorld.savedFile();
  expect(file.students, hasLength(students.toInt()));
  expect(file.attempts, hasLength(passes.toInt()));
}
