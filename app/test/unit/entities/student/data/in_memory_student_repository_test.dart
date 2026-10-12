import 'package:billard_cfa/entities/student/data/in_memory_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

Student student(String id, String name) => Student.enroll(
  id: StudentId(id),
  firstName: name,
  audience: Audience.children,
  since: day(1),
);

void main() {
  test('returns null for an unknown student', () async {
    expect(
      await InMemoryStudentRepository().byId(const StudentId('x')),
      isNull,
    );
  });

  test('stores and lists students', () async {
    final repository = InMemoryStudentRepository();
    await repository.save(student('s1', 'Léa'));
    await repository.save(student('s2', 'Théo'));

    expect(await repository.all(), hasLength(2));
    expect((await repository.byId(const StudentId('s2')))!.firstName, 'Théo');
  });

  test('replaces a student saved twice', () async {
    final repository = InMemoryStudentRepository();
    await repository.save(student('s1', 'Léa'));
    await repository.save(student('s1', 'Léa-Rose'));

    expect(await repository.all(), hasLength(1));
    expect(
      (await repository.byId(const StudentId('s1')))!.firstName,
      'Léa-Rose',
    );
  });
}
