import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> aucunLotNaDepasseSuppressions(
  WidgetTester tester,
  num limit,
) async {
  final batches = OwnMarkersWorld.current.rules.batches;
  expect(batches.length, greaterThan(1));
  expect(batches.every((size) => size <= limit), isTrue, reason: '$batches');
}
