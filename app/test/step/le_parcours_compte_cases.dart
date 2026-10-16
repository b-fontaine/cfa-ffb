import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le parcours compte {70} cases
Future<void> leParcoursCompteCases(WidgetTester tester, num count) async {
  final cells = TrackingWorld.current.sheet.path.fold<int>(
    0,
    (sum, row) => sum + row.summary.total,
  );
  expect(cells, count.toInt());
}
