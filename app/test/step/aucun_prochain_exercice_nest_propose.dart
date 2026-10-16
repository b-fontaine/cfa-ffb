import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: aucun prochain exercice n'est proposé
Future<void> aucunProchainExerciceNestPropose(WidgetTester tester) async {
  expect(TrackingWorld.current.sheet.header.next, isNull);
}
