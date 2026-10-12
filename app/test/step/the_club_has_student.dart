import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the club has {1} student
Future<void> theClubHasStudent(WidgetTester tester, num count) async {
  expect(await getIt<StudentRepository>().all(), hasLength(count.toInt()));
}
