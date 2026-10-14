import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: une saisie du groupe {'Jeunes'} le {'2026-10-05'} compte un passage
/// avec la séance inconnue {'inconnue-9'}
Future<void> uneSaisieDuGroupeLeCompteUnPassageAvecLaSeanceInconnue(
  WidgetTester tester,
  String group,
  String date,
  String sheet,
) async {
  await TrackingWorld.current.giveSessionOfUnknownSheet(
    group: group,
    on: TrackingWorld.date(date),
    sheet: SheetId(sheet),
  );
}
