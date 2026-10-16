import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'assiduité du groupe est de {7} présences sur {7} possibles en {2}
///   séances
Future<void> lassiduiteDuGroupeEstDePresencesSurPossiblesEnSeances(
  WidgetTester tester,
  num present,
  num possible,
  num sessions,
) async {
  final attendance = TrackingWorld.current.grid.attendance;
  expect(attendance.present, present.toInt());
  expect(attendance.possible, possible.toInt());
  expect(attendance.sessionCount, sessions.toInt());
}
