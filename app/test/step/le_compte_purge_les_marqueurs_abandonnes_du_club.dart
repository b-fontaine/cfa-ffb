import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> leComptePurgeLesMarqueursAbandonnesDuClub(
  WidgetTester tester,
  String name,
) async {
  await StaleMarkersWorld.current.purge(name);
}
