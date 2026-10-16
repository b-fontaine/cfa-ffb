import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la première alerte de groupe porte sur la technique {'posture'} du
///   groupe {'Jeunes'}
Future<void> laPremiereAlerteDeGroupePorteSurLaTechniqueDuGroupe(
  WidgetTester tester,
  String block,
  String group,
) async {
  final first = TrackingWorld.current.groupAlerts.lines.first;
  expect(first.alert.blockId, block);
  expect(first.groupId, TrackingWorld.groupId(group));
  expect(first.groupName, group);
}
