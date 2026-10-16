import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la semaine compte {1} passages, {0} validations et {1} séances
Future<void> laSemaineComptePassagesValidationsEtSeances(
  WidgetTester tester,
  num passes,
  num validations,
  num sessions,
) async {
  final week = TrackingWorld.current.week;
  expect(
    (
      passes: week.passes,
      validations: week.validations,
      sessions: week.sessions,
    ),
    (
      passes: passes.toInt(),
      validations: validations.toInt(),
      sessions: sessions.toInt(),
    ),
  );
}
