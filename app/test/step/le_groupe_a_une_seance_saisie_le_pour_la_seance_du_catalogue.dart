import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le groupe {'Jeunes'} a une séance saisie le {'2026-10-19'} pour la
/// séance du catalogue {'demi-bille-2'}
Future<void> leGroupeAUneSeanceSaisieLePourLaSeanceDuCatalogue(
  WidgetTester tester,
  String group,
  String date,
  String sheetId,
) async {
  final records = await TrackingWorld.recordsOn(group, date);
  expect(
    records.where((record) => record.sheetId?.value == sheetId),
    hasLength(1),
  );
}
