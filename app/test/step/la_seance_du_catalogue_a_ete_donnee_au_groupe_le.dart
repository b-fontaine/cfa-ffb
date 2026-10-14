import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance {'coule-2'} du catalogue a été donnée au groupe
/// {'Jeunes'} le {'2026-10-05'}
///
/// Saisie du groupe avec la séance du catalogue et un passage (S7).
Future<void> laSeanceDuCatalogueAEteDonneeAuGroupeLe(
  WidgetTester tester,
  String sheet,
  String group,
  String date,
) async {
  await TrackingWorld.current.giveSession(
    group: group,
    on: TrackingWorld.date(date),
    sheet: SheetId(sheet),
  );
}
