import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {3} alertes de groupe sont affichées sur {4}
Future<void> alertesDeGroupeSontAfficheesSur(
  WidgetTester tester,
  num shown,
  num total,
) async {
  final alerts = TrackingWorld.current.groupAlerts;
  expect(alerts.lines, hasLength(shown.toInt()));
  expect(alerts.total, total.toInt());
}
