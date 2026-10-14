import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lePassageReprendLaMainSurLexerciceAcquisAuPositionnement(
  WidgetTester tester,
) async {
  final recorded = TrackingWorld.valueOf(TrackingWorld.current.lastRecord);
  expect(recorded.resumedFromPlacement, isTrue);
}
