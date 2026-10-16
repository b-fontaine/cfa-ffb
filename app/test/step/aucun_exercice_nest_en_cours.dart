import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: aucun exercice n'est en cours
Future<void> aucunExerciceNestEnCours(WidgetTester tester) async {
  expect(TrackingWorld.current.sheet.header.current, isNull);
}
