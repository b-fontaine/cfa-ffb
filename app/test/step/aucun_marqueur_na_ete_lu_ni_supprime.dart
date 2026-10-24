import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> aucunMarqueurNaEteLuNiSupprime(WidgetTester tester) async {
  final rules = StaleMarkersWorld.current.rules;
  expect(rules.listed, isEmpty);
  expect(rules.batches, isEmpty);
}
