import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance {'posture-1'} du catalogue est ouverte au groupe
/// {'Jeunes'} le {'2026-10-05'} sans passage
Future<void> laSeanceDuCatalogueEstOuverteAuGroupeLeSansPassage(
  WidgetTester tester,
  String sheet,
  String group,
  String date,
) async {
  await TrackingWorld.current.giveSession(
    group: group,
    on: TrackingWorld.date(date),
    sheet: SheetId(sheet),
    withPass: false,
  );
}
