import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> laConnexionEstCoupeeApresLot(WidgetTester tester, num lots) async {
  OwnMarkersWorld.current.rules.failAfterBatches = lots.toInt();
}
