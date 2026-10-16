import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'exercice en cours compte {2} réussites sur {5}
Future<void> lexerciceEnCoursCompteReussitesSur(
  WidgetTester tester,
  num passed,
  num required,
) async {
  final header = TrackingWorld.current.sheet.header;
  expect(header.currentPassed, passed.toInt());
  expect(header.passesRequired, required.toInt());
}
