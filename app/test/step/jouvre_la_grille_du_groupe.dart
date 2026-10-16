import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'ouvre la grille du groupe {'Jeunes'}
Future<void> jouvreLaGrilleDuGroupe(WidgetTester tester, String group) async {
  await TrackingWorld.current.openGrid(group);
}
