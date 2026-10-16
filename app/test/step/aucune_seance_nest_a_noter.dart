import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: aucune séance n'est à noter
Future<void> aucuneSeanceNestANoter(WidgetTester tester) async {
  expect(TrackingWorld.current.upcoming.toRecord, isEmpty);
}
