import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Hugo'} quitte le groupe {'Jeunes'} le {'2026-10-01'}
Future<void> quitteLeGroupeLe(
  WidgetTester tester,
  String student,
  String group,
  String date,
) async {
  await TrackingWorld.current.leaveGroup(
    student,
    group,
    TrackingWorld.date(date),
  );
}
