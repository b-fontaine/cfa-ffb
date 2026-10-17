import 'package:billard_cfa/features/student_showcase/domain/list_linked_students.dart';
import 'package:billard_cfa/features/student_showcase/presentation/bloc/linked_students_cubit.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/club_world.dart';
import '../../../support/domain_world.dart';

void main() {
  late ClubWorld world;
  late ListLinkedStudents list;

  setUp(() async {
    world = ClubWorld();
    await world.seedLocalClub();
    list = ListLinkedStudents(world.local.students, world.scope, world.scope);
  });

  test(
    'a parent sees the students linked to the account, in link order',
    () async {
      world.signIn(
        Role.guardian,
        user: const UserId('u-anne'),
        studentIds: [const StudentId('s3'), const StudentId('s1')],
      );

      final students = ok(await list());

      expect([for (final s in students) s.firstName], ['Marc', 'Léa']);
    },
  );

  test('a student sees only their own fiche', () async {
    world.signIn(
      Role.student,
      user: const UserId('u-lea'),
      studentIds: [const StudentId('s1')],
    );

    expect([for (final s in ok(await list())) s.firstName], ['Léa']);
  });

  test(
    'a linked fiche that does not exist on this device is skipped',
    () async {
      world.signIn(
        Role.guardian,
        user: const UserId('u-anne'),
        studentIds: [const StudentId('s1'), const StudentId('inconnue')],
      );

      expect([for (final s in ok(await list())) s.firstName], ['Léa']);
    },
  );

  test('nobody linked sees nobody', () async {
    world.signIn(Role.guardian, user: const UserId('u-anne'));
    expect(ok(await list()), isEmpty);
  });

  test('an animator has no linked students to show', () async {
    world.signIn(Role.director, studentIds: [const StudentId('s1')]);
    expect(codeOf(await list()), InvariantCode.actionNotAllowed);
  });

  test('the cubit loads them and reports a failure', () async {
    world.signIn(
      Role.guardian,
      user: const UserId('u-anne'),
      studentIds: [const StudentId('s1')],
    );
    final cubit = LinkedStudentsCubit(list);
    expect(cubit.state.status, LinkedStudentsStatus.loading);

    await cubit.load();

    expect(cubit.state.status, LinkedStudentsStatus.ready);
    expect([for (final s in cubit.state.students) s.firstName], ['Léa']);

    world.signIn(Role.director);
    await cubit.load();
    expect(cubit.state.status, LinkedStudentsStatus.failed);
    expect(cubit.state.failure, isNotNull);
    await cubit.close();
  });
}
