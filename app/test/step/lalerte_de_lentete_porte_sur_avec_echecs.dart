import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'alerte de l'en-tête porte sur {'posture 1'} avec {3} échecs
Future<void> lalerteDeLentetePorteSurAvecEchecs(
  WidgetTester tester,
  String exercise,
  num failures,
) async {
  final alert = TrackingWorld.current.sheet.header.alert;
  expect(alert, isNotNull, reason: "l'en-tête n'a aucune alerte");
  expect(alert!.exercise, TrackingWorld.exercise(exercise));
  expect(alert.consecutiveFailures, failures.toInt());
}
