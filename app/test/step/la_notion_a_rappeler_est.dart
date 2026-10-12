import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> laNotionARappelerEst(WidgetTester tester, String block) async {
  expect(TrackingWorld.current.plan.recallBlockId, block);
}
