import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: aucune séance n'est en cours
Future<void> aucuneSeanceNestEnCours(WidgetTester tester) async {
  expect(TrackingWorld.current.running, isEmpty);
}
