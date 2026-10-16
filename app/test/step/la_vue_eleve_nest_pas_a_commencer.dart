import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: la vue élève n'est pas à commencer
Future<void> laVueEleveNestPasACommencer(WidgetTester tester) async {
  expect(TrackingWorld.current.showcase.toStart, isFalse);
}
