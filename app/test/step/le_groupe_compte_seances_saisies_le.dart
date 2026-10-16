import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le groupe {'Jeunes'} compte {2} séances saisies le {'2026-10-19'}
Future<void> leGroupeCompteSeancesSaisiesLe(
  WidgetTester tester,
  String group,
  num count,
  String date,
) async {
  expect(await TrackingWorld.recordsOn(group, date), hasLength(count.toInt()));
}
