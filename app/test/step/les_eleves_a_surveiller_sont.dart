import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: les élèves à surveiller sont {'Théo, Léa'} (dans cet ordre)
Future<void> lesElevesASurveillerSont(
  WidgetTester tester,
  String students,
) async {
  expect([
    for (final line in TrackingWorld.current.watchList.lines)
      line.student.firstName,
  ], TrackingWorld.names(students));
}
