import 'package:flutter_test/flutter_test.dart';

import '../support/closure_ops.dart';
import '../support/tracking_world.dart';

/// Usage: la saison {'2026-2027'} se termine le {'2026-10-12'}
Future<void> laSaisonSeTermineLe(
  WidgetTester tester,
  String label,
  String date,
) async {
  final season = await ClosureOps.season(label);
  expect(season.endDate, TrackingWorld.date(date));
}
