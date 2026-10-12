import 'package:billard_cfa/features/manage_students/domain/get_student.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';

void main() {
  late DomainWorld world;
  late GetStudent getStudent;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1']);
    getStudent = GetStudent(world.students);
  });

  test('gives the student', () async {
    final student = ok(await getStudent(const StudentId('s1')));

    expect(student.firstName, 's1');
  });

  test('refuses an unknown student', () async {
    final result = await getStudent(const StudentId('nope'));

    expect(
      err(result),
      isA<NotFound>().having((e) => e.kind, 'kind', 'student'),
    );
  });
}
