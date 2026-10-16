import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Zoé'} est inscrite au club sans aucun groupe
Future<void> estInscriteAuClubSansAucunGroupe(
  WidgetTester tester,
  String student,
) async {
  await TrackingWorld.current.addUngrouped(student);
}
