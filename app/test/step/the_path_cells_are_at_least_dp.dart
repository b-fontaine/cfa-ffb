import 'package:flutter_test/flutter_test.dart';

import '../support/key_finders.dart';

/// Usage: the path cells are at least {48} dp
///
/// Chaque case du parcours offre une cible tactile d'au moins [size] dp.
Future<void> thePathCellsAreAtLeastDp(WidgetTester tester, num size) async {
  final cells = byKeyPrefix('path-cell-');
  expect(cells, findsWidgets);
  for (final element in cells.evaluate()) {
    final box = tester.getSize(find.byElementPredicate((e) => e == element));
    expect(box.width, greaterThanOrEqualTo(size), reason: 'case trop étroite');
    expect(box.height, greaterThanOrEqualTo(size), reason: 'case trop basse');
  }
}
