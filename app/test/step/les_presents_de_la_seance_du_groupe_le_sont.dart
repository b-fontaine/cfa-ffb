import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: les présents de la séance du groupe {'Jeunes'} le {'2026-10-05'} sont
///   {'Léa, Théo'}
Future<void> lesPresentsDeLaSeanceDuGroupeLeSont(
  WidgetTester tester,
  String group,
  String date,
  String names,
) async {
  final records = await TrackingWorld.recordsOn(group, date);
  expect(records, hasLength(1));
  expect(
    [for (final id in records.single.present) id.value]..sort(),
    [for (final name in TrackingWorld.names(names)) 'student-$name']..sort(),
  );
}
