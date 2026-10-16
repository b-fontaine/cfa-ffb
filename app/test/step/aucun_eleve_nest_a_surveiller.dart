import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: aucun élève n'est à surveiller
Future<void> aucunEleveNestASurveiller(WidgetTester tester) async {
  expect(TrackingWorld.current.watchList.total, 0);
  expect(TrackingWorld.current.watchList.lines, isEmpty);
}
