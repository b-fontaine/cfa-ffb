import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Léa, Théo'} ont échoué {1} passages sur {'bille-pleine 1'} le
///   {'2026-10-12'}
Future<void> ontEchouePassagesSurLe(
  WidgetTester tester,
  String students,
  num count,
  String exercise,
  String date,
) async {
  for (final student in TrackingWorld.names(students)) {
    await TrackingWorld.current.seedPassesOn(
      student,
      TrackingWorld.exercise(exercise),
      count.toInt(),
      on: TrackingWorld.date(date),
      passed: false,
    );
  }
}
