import 'package:flutter_test/flutter_test.dart';

import '../support/key_finders.dart';

/// Usage: the grid cells are at least {48} dp
Future<void> theGridCellsAreAtLeastDp(WidgetTester tester, num size) async {
  final cells = byKeyPrefix('heat-cell-');
  expect(cells, findsWidgets);
  for (final element in cells.evaluate()) {
    final box = tester.getSize(find.byElementPredicate((e) => e == element));
    expect(
      box.width,
      greaterThanOrEqualTo(size),
      reason: 'cellule trop étroite',
    );
    expect(
      box.height,
      greaterThanOrEqualTo(size),
      reason: 'cellule trop basse',
    );
  }
}
