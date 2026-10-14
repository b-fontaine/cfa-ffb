import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the club keeps no data for {'Léa'}
///
/// Aucun élève de ce prénom, et aucune donnée (passage, bilan, bloc acquis,
/// présence, appartenance) ne nomme un élève qui n'existe plus.
Future<void> theClubKeepsNoDataFor(WidgetTester tester, String name) async {
  final students = await getIt<StudentRepository>().all();
  final known = {for (final student in students) student.id};

  expect(students.where((s) => s.firstName == name), isEmpty);
  for (final attempt in await getIt<AttemptRepository>().all()) {
    expect(known, contains(attempt.studentId));
  }
  for (final assessment in await getIt<AssessmentRepository>().all()) {
    expect(known, contains(assessment.studentId));
  }
  for (final acquisition in await getIt<AcquisitionRepository>().all()) {
    expect(known, contains(acquisition.studentId));
  }
  for (final session in await getIt<SessionRecordRepository>().all()) {
    expect(known.containsAll(session.present), isTrue);
  }
  for (final group in await getIt<GroupRepository>().all()) {
    expect(group.memberships.every((m) => known.contains(m.studentId)), isTrue);
  }
}
