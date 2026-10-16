import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Ana'} est inscrite au groupe {'Jeunes'} depuis le {'2025-09-15'}
Future<void> estInscriteAuGroupeDepuisLe(
  WidgetTester tester,
  String student,
  String group,
  String date,
) async {
  await TrackingWorld.current.addVeteran(
    group: group,
    student: student,
    enrolledOn: TrackingWorld.date(date),
  );
}
