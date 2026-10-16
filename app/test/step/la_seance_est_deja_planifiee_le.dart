import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance {'posture-2'} est déjà planifiée le {'2026-10-19'}
Future<void> laSeanceEstDejaPlanifieeLe(
  WidgetTester tester,
  String sheet,
  String date,
) async {
  final review = TrackingWorld.valueOf(TrackingWorld.current.reviewResult);
  expect(review.plannedFor(SheetId(sheet))?.date, TrackingWorld.date(date));
}
