import 'package:billard_cfa/features/manage_students/domain/rename_student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';

void main() {
  late DomainWorld world;
  late RenameStudent rename;

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1']);
    rename = RenameStudent(world.students);
  });

  test('changes the first name and keeps the audience history', () async {
    final student = ok(
      await rename(studentId: const StudentId('s1'), firstName: ' Léo '),
    );

    expect(student.firstName, 'Léo');
    expect(student.currentAudience, Audience.children);
    expect(await world.students.byId(const StudentId('s1')), student);
  });

  test('refuses a blank name and keeps the old one', () async {
    final result = await rename(
      studentId: const StudentId('s1'),
      firstName: ' ',
    );

    expect(codeOf(result), InvariantCode.blankName);
    final stored = await world.students.byId(const StudentId('s1'));
    expect(stored!.firstName, 's1');
  });

  test('refuses an unknown student', () async {
    final result = await rename(
      studentId: const StudentId('nope'),
      firstName: 'Léo',
    );

    expect(err(result), isA<NotFound>());
  });

  test('accepts a first name of 40 characters and refuses 41', () async {
    final ok40 = await rename(
      studentId: const StudentId('s1'),
      firstName: 'é' * 40,
    );
    expect(ok(ok40).firstName, 'é' * 40);

    final tooLong = await rename(
      studentId: const StudentId('s1'),
      firstName: 'é' * 41,
    );
    expect(codeOf(tooLong), InvariantCode.nameTooLong);
    final stored = await world.students.byId(const StudentId('s1'));
    expect(stored!.firstName, 'é' * 40);
  });
}
