import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Léa'} a échoué {1} passages sur {'posture 1'} le {'2026-10-12'}
Future<void> aEchouePassagesSurLe(
  WidgetTester tester,
  String student,
  num count,
  String exercise,
  String date,
) async {
  await TrackingWorld.current.seedPassesOn(
    student,
    TrackingWorld.exercise(exercise),
    count.toInt(),
    on: TrackingWorld.date(date),
    passed: false,
  );
}
