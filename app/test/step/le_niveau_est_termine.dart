import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: le niveau est terminé
Future<void> leNiveauEstTermine(WidgetTester tester) async {
  expect(TrackingWorld.current.sheet.header.levelCompleted, isTrue);
}
