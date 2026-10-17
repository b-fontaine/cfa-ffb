import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance saisie du groupe {'Jeunes'} le {'2026-10-19'} ne porte
/// aucune étiquette
Future<void> laSeanceSaisieDuGroupeLeNePorteAucuneEtiquette(
  WidgetTester tester,
  String group,
  String date,
) async {
  final record = (await TrackingWorld.recordsOn(group, date)).single;
  expect(record.tags, isEmpty);
}
