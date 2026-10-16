import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le groupe n'a aucune alerte
Future<void> leGroupeNaAucuneAlerte(WidgetTester tester) async {
  expect(TrackingWorld.current.grid.alerts, isEmpty);
}
