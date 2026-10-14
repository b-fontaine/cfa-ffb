import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la saisie du groupe {'Jeunes'} du {'2026-10-05'} est reprise avec
/// la séance {'posture-2'}
Future<void> laSaisieDuGroupeDuEstRepriseAvecLaSeance(
  WidgetTester tester,
  String group,
  String date,
  String sheet,
) async {
  await TrackingWorld.current.resumeSession(
    group: group,
    on: TrackingWorld.date(date),
    sheet: SheetId(sheet),
  );
}
