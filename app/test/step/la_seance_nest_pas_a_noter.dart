import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance {'posture-2'} n'est pas à noter
Future<void> laSeanceNestPasANoter(WidgetTester tester, String sheet) async {
  expect([
    for (final s in TrackingWorld.current.upcoming.toRecord) s.session.sheetId,
  ], isNot(contains(SheetId(sheet))));
}
