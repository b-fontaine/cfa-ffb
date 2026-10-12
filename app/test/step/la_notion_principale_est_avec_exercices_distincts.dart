import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> laNotionPrincipaleEstAvecExercicesDistincts(
  WidgetTester tester,
  String block,
  num count,
) async {
  final plan = TrackingWorld.current.plan;
  expect(plan.mainBlockId, block);
  expect(plan.exercises.toSet(), hasLength(count.toInt()));
}
