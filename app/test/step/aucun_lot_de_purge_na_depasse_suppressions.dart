import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> aucunLotDePurgeNaDepasseSuppressions(
  WidgetTester tester,
  num max,
) async {
  final batches = StaleMarkersWorld.current.rules.batches;
  expect(batches, isNotEmpty);
  expect(batches.every((size) => size <= max), isTrue, reason: '$batches');
}
