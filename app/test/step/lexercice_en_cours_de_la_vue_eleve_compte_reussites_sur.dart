import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'exercice en cours de la vue élève compte {2} réussites sur {5}
Future<void> lexerciceEnCoursDeLaVueEleveCompteReussitesSur(
  WidgetTester tester,
  num passed,
  num required,
) async {
  final current = TrackingWorld.current.showcase.current!;
  expect(current.passed, passed.toInt());
  expect(current.required, required.toInt());
}
