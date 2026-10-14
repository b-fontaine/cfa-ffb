import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le
/// {'2026-10-05'}
Future<void> laSeanceEstPlanifieePourLeGroupeLe(
  WidgetTester tester,
  String sheet,
  String group,
  String date,
) async {
  await TrackingWorld.current.planSheet(
    group: group,
    on: TrackingWorld.date(date),
    sheet: SheetId(sheet),
  );
}
