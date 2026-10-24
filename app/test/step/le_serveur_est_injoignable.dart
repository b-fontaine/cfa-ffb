import 'package:flutter_test/flutter_test.dart';

import '../support/stale_markers_world.dart';

Future<void> leServeurEstInjoignable(WidgetTester tester) async {
  StaleMarkersWorld.current.rules.offline = true;
}
