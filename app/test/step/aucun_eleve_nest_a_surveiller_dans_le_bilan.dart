import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: aucun élève n'est à surveiller dans le bilan
Future<void> aucunEleveNestASurveillerDansLeBilan(WidgetTester tester) async {
  final outcome = TrackingWorld.valueOf(TrackingWorld.current.reviewResult)
      .outcome;
  expect(outcome.watched, isEmpty);
}
