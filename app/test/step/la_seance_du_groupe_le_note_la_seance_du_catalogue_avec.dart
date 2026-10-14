import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance du groupe {'Jeunes'} le {'2026-10-19'} note la séance du
/// catalogue {'demi-bille-2'} avec {'Léa'}
Future<void> laSeanceDuGroupeLeNoteLaSeanceDuCatalogueAvec(
  WidgetTester tester,
  String group,
  String date,
  String sheetId,
  String students,
) async {
  await TrackingWorld.current.openSession(
    group: group,
    on: TrackingWorld.date(date),
    present: TrackingWorld.names(students),
    sheet: SheetId(sheetId),
  );
}
