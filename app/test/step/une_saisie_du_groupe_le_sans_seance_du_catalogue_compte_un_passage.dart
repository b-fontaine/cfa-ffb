import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: une saisie du groupe {'Jeunes'} le {'2026-10-05'} sans séance du
/// catalogue compte un passage
Future<void> uneSaisieDuGroupeLeSansSeanceDuCatalogueCompteUnPassage(
  WidgetTester tester,
  String group,
  String date,
) async {
  await TrackingWorld.current.giveSession(
    group: group,
    on: TrackingWorld.date(date),
  );
}
