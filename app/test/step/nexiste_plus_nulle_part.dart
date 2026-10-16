import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tracking_world.dart';

/// Usage: {'Hugo'} n'existe plus nulle part
Future<void> nexistePlusNullePart(WidgetTester tester, String student) async {
  final id = TrackingWorld.studentId(student);
  expect(await getIt<StudentRepository>().byId(id), isNull);
  expect(await getIt<AttemptRepository>().forStudent(id), isEmpty);
  for (final session in await getIt<SessionRecordRepository>().all()) {
    expect(session.present, isNot(contains(id)));
  }
  for (final group in await getIt<GroupRepository>().all()) {
    expect(group.memberships.map((m) => m.studentId), isNot(contains(id)));
  }
  expect(
    (await getIt<AssessmentRepository>().all()).map((a) => a.studentId),
    isNot(contains(id)),
  );
  expect(
    (await getIt<AcquisitionRepository>().all()).map((a) => a.studentId),
    isNot(contains(id)),
  );
  expect(
    (await getIt<AcknowledgementRepository>().all()).map((a) => a.studentId),
    isNot(contains(id)),
  );
}
