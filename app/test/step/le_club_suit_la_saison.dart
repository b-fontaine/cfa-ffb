import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> leClubSuitLaSaison(WidgetTester tester, String label) async {
  await TrackingWorld.open(tester, label);
}
