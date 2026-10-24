import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> leDirecteurOuvreLaPurgeDesMarqueursAbandonnesDeMonClub(
  WidgetTester tester,
) async {
  await StaleMarkersWorld.current.openCard(tester);
}
