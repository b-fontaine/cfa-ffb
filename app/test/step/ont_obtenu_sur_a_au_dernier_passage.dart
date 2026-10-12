import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> ontObtenuSurAAuDernierPassage(
  WidgetTester tester,
  String students,
  num potted,
  num total,
  String exercise,
) async {
  for (final student in TrackingWorld.names(students)) {
    await TrackingWorld.current.seedPass(
      student,
      TrackingWorld.exercise(exercise),
      potted: potted.toInt(),
      total: total.toInt(),
    );
  }
}
