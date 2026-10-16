import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Eve'} rejoint le groupe {'Jeunes'} le {'2026-10-08'}
Future<void> rejointLeGroupeLe(
  WidgetTester tester,
  String student,
  String group,
  String date,
) async {
  await TrackingWorld.current.joinGroup(
    student,
    group,
    TrackingWorld.date(date),
  );
}
