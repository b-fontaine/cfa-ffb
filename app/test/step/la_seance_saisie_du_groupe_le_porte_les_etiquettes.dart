import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la séance saisie du groupe {'Jeunes'} le {'2026-10-19'} porte les
/// étiquettes {'tooLong,toRedo'}
Future<void> laSeanceSaisieDuGroupeLePorteLesEtiquettes(
  WidgetTester tester,
  String group,
  String date,
  String codes,
) async {
  final record = (await TrackingWorld.recordsOn(group, date)).single;
  expect(record.tags, TrackingWorld.tags(codes));
}
