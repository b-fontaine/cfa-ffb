import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> lexerciceResteEnCoursAvecPassagesReussisSur(
  WidgetTester tester,
  String exercise,
  num passed,
  num required,
) async {
  final recorded = TrackingWorld.valueOf(TrackingWorld.current.lastRecord);
  expect(recorded.attempt.exercise, TrackingWorld.exercise(exercise));
  expect(recorded.result.status, ExerciseStatus.inProgress);
  expect(recorded.result.passedCount, passed);
  expect(RulesConfig().passesRequired, required);
}
