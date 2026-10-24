import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> marqueursAbandonnesOntEteSupprimes(
  WidgetTester tester,
  num count,
) async {
  final result = StaleMarkersWorld.current.result;
  expect(result?.removed, count.toInt());
}
