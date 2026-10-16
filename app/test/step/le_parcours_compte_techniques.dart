import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le parcours compte {15} techniques
Future<void> leParcoursCompteTechniques(WidgetTester tester, num count) async {
  expect(TrackingWorld.current.sheet.path, hasLength(count.toInt()));
}
