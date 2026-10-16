import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance {'posture-1'} est à noter
Future<void> laSeanceEstANoter(WidgetTester tester, String sheet) async {
  expect([
    for (final s in TrackingWorld.current.upcoming.toRecord) s.session.sheetId,
  ], contains(SheetId(sheet)));
}
