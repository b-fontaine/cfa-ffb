import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> ecrituresOntDejaEteFaitesAujourdhuiSurCetAppareil(
  WidgetTester tester,
  num writes,
) async {
  await StaleMarkersWorld.current.ledger.add(writes.toInt());
}
