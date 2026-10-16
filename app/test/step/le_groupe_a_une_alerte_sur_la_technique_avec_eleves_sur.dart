import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le groupe a une alerte sur la technique {'posture'} avec {2} élèves
///   sur {3}
Future<void> leGroupeAUneAlerteSurLaTechniqueAvecElevesSur(
  WidgetTester tester,
  String block,
  num failed,
  num members,
) async {
  final alerts = TrackingWorld.current.grid.alerts.where(
    (alert) => alert.blockId == block,
  );
  expect(alerts, hasLength(1), reason: "pas d'alerte de groupe sur $block");
  expect(alerts.single.failed, failed.toInt());
  expect(alerts.single.members, members.toInt());
}
