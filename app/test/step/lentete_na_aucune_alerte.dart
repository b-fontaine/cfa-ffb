import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'en-tête n'a aucune alerte
Future<void> lenteteNaAucuneAlerte(WidgetTester tester) async {
  expect(TrackingWorld.current.sheet.header.alert, isNull);
}
