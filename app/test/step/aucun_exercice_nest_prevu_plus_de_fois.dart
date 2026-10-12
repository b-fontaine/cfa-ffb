import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> aucunExerciceNestPrevuPlusDeFois(
  WidgetTester tester,
  num limit,
) async {
  final plan = TrackingWorld.current.plan;
  expect(
    plan.plannedExercises.toSet(),
    hasLength(plan.plannedExercises.length),
  );
  expect(plan.maxPassesPerExercise, lessThanOrEqualTo(limit));
}
