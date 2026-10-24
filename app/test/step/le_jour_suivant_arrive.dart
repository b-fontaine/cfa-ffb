import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> leJourSuivantArrive(WidgetTester tester) async {
  StaleMarkersWorld.current.clock.advance(const Duration(days: 1));
}
