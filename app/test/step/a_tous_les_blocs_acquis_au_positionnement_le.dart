import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Léa'} a tous les blocs acquis au positionnement le {'2026-10-12'}
Future<void> aTousLesBlocsAcquisAuPositionnementLe(
  WidgetTester tester,
  String student,
  String date,
) async {
  final world = TrackingWorld.current;
  for (final block in world.catalogue.blocks) {
    await world.markAcquired(student, block.id, TrackingWorld.date(date));
  }
}
