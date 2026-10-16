import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: j'ouvre la vue élève de {'Zoé'}
Future<void> jouvreLaVueEleveDe(WidgetTester tester, String student) async {
  await TrackingWorld.current.openShowcase(student);
}
