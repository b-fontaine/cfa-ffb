import 'package:flutter_test/flutter_test.dart';

import '../support/own_markers_world.dart';

Future<void> aucuneListeDeMarqueursNaEteDemandee(WidgetTester tester) async {
  expect(OwnMarkersWorld.current.rules.listed, isEmpty);
}
