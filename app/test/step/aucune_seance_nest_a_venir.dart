import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: aucune séance n'est à venir
Future<void> aucuneSeanceNestAVenir(WidgetTester tester) async {
  expect(TrackingWorld.current.upcoming.next, isNull);
}
