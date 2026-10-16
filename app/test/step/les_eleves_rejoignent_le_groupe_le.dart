import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: les élèves {'Ana, Bob, Cléo, Dan, Eli'} rejoignent le groupe
///   {'Jeunes'} le {'2026-09-01'}
Future<void> lesElevesRejoignentLeGroupeLe(
  WidgetTester tester,
  String students,
  String group,
  String date,
) async {
  for (final student in TrackingWorld.names(students)) {
    await TrackingWorld.current.joinGroup(
      student,
      group,
      TrackingWorld.date(date),
    );
  }
}
