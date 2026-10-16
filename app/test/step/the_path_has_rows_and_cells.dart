import 'package:flutter_test/flutter_test.dart';

import '../support/key_finders.dart';

/// Usage: the path has {15} rows and {70} cells
Future<void> thePathHasRowsAndCells(
  WidgetTester tester,
  num rows,
  num cells,
) async {
  expect(byKeyPrefix('path-row-'), findsNWidgets(rows.toInt()));
  expect(byKeyPrefix('path-cell-'), findsNWidgets(cells.toInt()));
}
