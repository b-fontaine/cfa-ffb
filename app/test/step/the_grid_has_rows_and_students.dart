import 'package:flutter_test/flutter_test.dart';

import '../support/key_finders.dart';

/// Usage: the grid has {15} rows and {2} students
Future<void> theGridHasRowsAndStudents(
  WidgetTester tester,
  num rows,
  num students,
) async {
  expect(byKeyPrefix('heat-row-'), findsNWidgets(rows.toInt()));
  expect(byKeyPrefix('heat-column-'), findsNWidgets(students.toInt()));
}
