import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart';
import 'package:billard_cfa/features/track_progress/domain/get_student_report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

Future<void> leNiveauDalerteDeSurEst(
  WidgetTester tester,
  String student,
  String exercise,
  String level,
) async {
  final report = TrackingWorld.valueOf(
    await getIt<GetStudentReport>()(TrackingWorld.studentId(student)),
  );
  final ref = TrackingWorld.exercise(exercise);
  final active = report.activeAlerts.where((r) => r.exercise == ref);
  final actual = active.isEmpty ? AlertLevel.none : active.single.alert;
  expect(actual.name, switch (level) {
    'aucune' => 'none',
    'attention' => 'attention',
    'persistante' => 'persistent',
    _ => level,
  });
}
