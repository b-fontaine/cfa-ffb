import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'en-tête compte {15} techniques terminées sur {15}
Future<void> lenteteCompteTechniquesTermineesSur(
  WidgetTester tester,
  num finished,
  num total,
) async {
  final header = TrackingWorld.current.sheet.header;
  expect(header.finishedTechniques, finished.toInt());
  expect(header.techniqueCount, total.toInt());
}
