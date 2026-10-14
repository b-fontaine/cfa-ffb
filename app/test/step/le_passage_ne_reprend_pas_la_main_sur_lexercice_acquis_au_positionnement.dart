import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lePassageNeReprendPasLaMainSurLexerciceAcquisAuPositionnement(
  WidgetTester tester,
) async {
  final recorded = TrackingWorld.valueOf(TrackingWorld.current.lastRecord);
  expect(recorded.resumedFromPlacement, isFalse);
}
