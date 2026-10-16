import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'ouvre les alertes de groupe
Future<void> jouvreLesAlertesDeGroupe(WidgetTester tester) async {
  await TrackingWorld.current.openGroupAlerts();
}
