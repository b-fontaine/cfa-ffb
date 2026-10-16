import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: l'exercice en cours de la vue élève est {'posture 2'}
Future<void> lexerciceEnCoursDeLaVueEleveEst(
  WidgetTester tester,
  String exercise,
) async {
  final ref = TrackingWorld.exercise(exercise);
  final current = TrackingWorld.current.showcase.current;
  expect(current, isNotNull);
  expect(current!.number, ref.number);
  expect(
    current.blockTitle,
    TrackingWorld.current.catalogue.blockById(ref.blockId)!.title,
  );
}
