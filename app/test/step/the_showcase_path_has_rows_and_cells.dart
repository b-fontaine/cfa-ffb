import 'package:flutter_test/flutter_test.dart';

import '../support/key_finders.dart';

/// Usage: the showcase path has {15} rows and {70} cells
Future<void> theShowcasePathHasRowsAndCells(
  WidgetTester tester,
  num rows,
  num cells,
) async {
  expect(byKeyPrefix('showcase-row-'), findsNWidgets(rows.toInt()));
  expect(byKeyPrefix('showcase-cell-'), findsNWidgets(cells.toInt()));
}
