import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'alerte de l'en-tête sur {'posture 1'} est vue le {'2026-10-12'}
Future<void> lalerteDeLenteteSurEstVueLe(
  WidgetTester tester,
  String exercise,
  String date,
) async {
  final seen = TrackingWorld.current.sheet.header.acknowledged.where(
    (alert) => alert.exercise == TrackingWorld.exercise(exercise),
  );
  expect(seen, hasLength(1), reason: "l'alerte n'est pas marquée vue");
  expect(seen.single.date, TrackingWorld.date(date));
}
