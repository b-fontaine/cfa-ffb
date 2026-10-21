import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the local data still hold {6} students and {72} passes
///
/// Ni l'export ni le bandeau ne modifient les données de l'appareil.
Future<void> theLocalDataStillHoldStudentsAndPasses(
  WidgetTester tester,
  num students,
  num passes,
) async {
  await tester.runAsync(() async {
    expect(await getIt<StudentRepository>().all(), hasLength(students.toInt()));
    expect(await getIt<AttemptRepository>().all(), hasLength(passes.toInt()));
  });
}
