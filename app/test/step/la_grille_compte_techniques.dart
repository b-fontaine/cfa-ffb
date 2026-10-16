import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la grille compte {15} techniques
Future<void> laGrilleCompteTechniques(WidgetTester tester, num count) async {
  expect(TrackingWorld.current.grid.rows, hasLength(count.toInt()));
}
