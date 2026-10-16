import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Léa'} est à surveiller pour {'posture 1'} avec {3} échecs de
/// suite au niveau {'attention'}
Future<void> estASurveillerPourAvecEchecsDeSuiteAuNiveau(
  WidgetTester tester,
  String student,
  String exercise,
  num failures,
  String level,
) async {
  final line = TrackingWorld.current.watchList.lines.firstWhere(
    (line) => line.student.id == TrackingWorld.studentId(student),
    orElse: () => fail("$student n'est pas à surveiller"),
  );
  expect(line.watched.exercise, TrackingWorld.exercise(exercise));
  expect(line.watched.consecutiveFailures, failures.toInt());
  expect(
    line.watched.alert,
    level == 'persistante' ? AlertLevel.persistent : AlertLevel.attention,
  );
}
