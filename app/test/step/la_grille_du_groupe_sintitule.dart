import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la grille du groupe s'intitule {'Débutants'}
Future<void> laGrilleDuGroupeSintitule(WidgetTester tester, String name) async {
  expect(TrackingWorld.current.grid.name, name);
}
