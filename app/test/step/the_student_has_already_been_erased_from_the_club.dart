import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the student {'Tom'} has already been erased from the club
///
/// La fiche est effacée (droit à l'effacement, `StudentRepository.erase`),
/// mais le `member` du parent la cite encore : la suppression de son compte
/// ne lit aucune fiche et ne doit pas en dépendre.
Future<void> theStudentHasAlreadyBeenErasedFromTheClub(
  WidgetTester tester,
  String name,
) async {
  await tester.runAsync(() async {
    final students = UiWorld.seedGraph<StudentRepository>();
    await students.erase((await UiWorld.studentNamed(name)).id);
    expect(
      (await students.all()).where((student) => student.firstName == name),
      isEmpty,
    );
  });
}
