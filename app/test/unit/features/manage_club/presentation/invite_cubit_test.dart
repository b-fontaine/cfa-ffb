import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/features/manage_club/domain/issue_invitation.dart';
import 'package:billard_cfa/features/manage_club/domain/list_invitable_groups.dart';
import 'package:billard_cfa/features/manage_club/domain/list_invitable_students.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_cubit.dart';
import 'package:billard_cfa/features/manage_club/presentation/bloc/invite_state.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/club_world.dart';

void main() {
  late ClubWorld world;
  const g1 = GroupId('g1');
  const s1 = StudentId('s1');
  const s2 = StudentId('s2');
  const s3 = StudentId('s3');

  InviteCubit cubit() {
    final issued = IssuedInvitations(world.log, world.invitations, world.clock);
    return InviteCubit(
      ListInvitableStudents(
        world.local.students,
        world.local.groups,
        world.local.seasons,
        world.clock,
        world.scope,
        world.scope,
      ),
      ListInvitableGroups(
        world.local.groups,
        world.local.seasons,
        world.clock,
        world.scope,
        world.scope,
      ),
      IssueInvitation(
        world.invitations,
        world.directory,
        world.codes,
        issued,
        world.local.students,
        world.local.groups,
        world.local.seasons,
        world.clock,
        world.scope,
        world.scope,
      ),
      world.scope,
    );
  }

  setUp(() async {
    world = ClubWorld();
    await world.seedLocalClub();
  });

  test('the director may invite a teacher, a student or a parent', () async {
    world.signIn(Role.director);
    final c = cubit();

    await c.load();

    expect(c.state.load, InviteLoad.ready);
    expect(c.state.roles, [Role.teacher, Role.student, Role.guardian]);
    expect(
      [for (final s in c.state.students) s.student.firstName],
      ['Léa', 'Marc', 'Tom'],
    );
    expect([for (final g in c.state.groups) g.name], ['Jeudi', 'Mardi']);
    expect(c.state.role, isNull);
    await c.close();
  });

  test(
    'a teacher may invite a student or a parent of their groups only',
    () async {
      world.signIn(
        Role.teacher,
        user: const UserId('u-sophie'),
        groupIds: [g1],
      );
      final c = cubit();

      await c.load();

      expect(c.state.roles, [Role.student, Role.guardian]);
      expect(
        [for (final s in c.state.students) s.student.firstName],
        ['Léa', 'Tom'],
      );
      expect(
        c.state.groups,
        isEmpty,
        reason: 'un enseignant n’invite pas d’enseignant',
      );
      await c.close();
    },
  );

  test('a student has no invitation to make: nothing is proposed', () async {
    world.signIn(Role.student, user: const UserId('u-x'));
    final c = cubit();

    await c.load();

    expect(c.state.load, InviteLoad.failed);
    expect(
      (c.state.failure! as InvariantViolation).code,
      InvariantCode.actionNotAllowed,
    );
    expect(c.state.roles, isEmpty);
    await c.close();
  });

  test('the local lists do not need the server', () async {
    world.signIn(Role.director);
    world.store.failing = StoreFailureCode.unavailable;
    final c = cubit();

    await c.load();

    expect(
      c.state.load,
      InviteLoad.ready,
      reason: 'les listes viennent de l’appareil',
    );
    await c.close();
  });

  test('choosing a role forgets the choices of another role', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    c
      ..selectRole(Role.teacher)
      ..toggleGroup(g1)
      ..selectRole(Role.guardian)
      ..toggleStudent(s1)
      ..setAgeConfirmed(value: true)
      ..selectRole(Role.student);

    expect(c.state.role, Role.student);
    expect(c.state.selectedGroups, isEmpty);
    expect(c.state.selectedStudents, isEmpty);
    expect(c.state.ageConfirmed, isFalse);
    await c.close();
  });

  test('a role that cannot be invited is ignored', () async {
    world.signIn(Role.teacher, user: const UserId('u-sophie'), groupIds: [g1]);
    final c = cubit();
    await c.load();

    c.selectRole(Role.teacher);

    expect(c.state.role, isNull);
    await c.close();
  });

  test('groups are toggled on and off', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    c
      ..selectRole(Role.teacher)
      ..toggleGroup(g1);
    expect(c.state.selectedGroups, {g1});
    c.toggleGroup(g1);
    expect(c.state.selectedGroups, isEmpty);
    await c.close();
  });

  test('a student invitation holds one student: the newest replaces', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    c
      ..selectRole(Role.student)
      ..toggleStudent(s1)
      ..toggleStudent(s2);

    expect(c.state.selectedStudents, {s2});
    c.toggleStudent(s2);
    expect(c.state.selectedStudents, isEmpty);
    await c.close();
  });

  test('a parent invitation holds up to four children', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    c.selectRole(Role.guardian);

    [
      s1,
      s2,
      s3,
      const StudentId('s4'),
      const StudentId('s5'),
    ].forEach(c.toggleStudent);

    expect(c.state.selectedStudents, hasLength(4));
    expect(c.state.selectedStudents, isNot(contains(const StudentId('s5'))));
    await c.close();
  });

  test('creates the invitation and shows it', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    c
      ..selectRole(Role.guardian)
      ..toggleStudent(s1);

    await c.submit();

    expect(c.state.submitting, isFalse);
    expect(c.state.issued, isNotNull);
    expect(c.state.issued!.studentIds, [s1]);
    expect(c.state.failure, isNull);
    expect(world.doc('invitations/${c.state.issued!.code.value}'), isNotNull);
    await c.close();
  });

  test('without a role, submit does nothing', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();

    await c.submit();

    expect(c.state.issued, isNull);
    expect(world.store.commits, 0);
    await c.close();
  });

  test('a refusal shows the failure and keeps the choices', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    c
      ..selectRole(Role.student)
      ..toggleStudent(s1);

    await c.submit();

    expect(
      (c.state.failure! as InvariantViolation).code,
      InvariantCode.ageConfirmationRequired,
    );
    expect(c.state.selectedStudents, {s1});
    expect(c.state.issued, isNull);

    c.setAgeConfirmed(value: true);
    expect(c.state.failure, isNull, reason: 'une correction efface l’erreur');
    await c.submit();
    expect(c.state.issued, isNotNull);
    await c.close();
  });

  test('another returns to an empty form and keeps the lists', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    c.selectRole(Role.teacher);
    await c.submit();
    expect(c.state.issued, isNotNull);

    c.another();

    expect(c.state.issued, isNull);
    expect(c.state.role, isNull);
    expect(c.state.groups, isNotEmpty);
    await c.close();
  });

  test('a second submit while the first one runs is ignored', () async {
    world.signIn(Role.director);
    final c = cubit();
    await c.load();
    c.selectRole(Role.teacher);

    final first = c.submit();
    final second = c.submit();
    await Future.wait([first, second]);

    expect(
      world.store.documents.keys.where((p) => p.startsWith('invitations/')),
      hasLength(1),
    );
    await c.close();
  });
}
