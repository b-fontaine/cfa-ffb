import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-12'} avec
///   {'Léa, Théo, Hugo, Eve'}
Future<void> uneSeanceDuGroupeAEuLieuLeAvec(
  WidgetTester tester,
  String group,
  String date,
  String students,
) async {
  await TrackingWorld.current.holdSessionWith(
    group,
    TrackingWorld.date(date),
    TrackingWorld.names(students),
  );
}
