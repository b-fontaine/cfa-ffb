import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/entities/invitation/domain/issued_invitations.dart';
import 'package:billard_cfa/features/manage_club/domain/issue_invitation.dart';
import 'package:billard_cfa/features/manage_club/domain/list_invitable_students.dart';
import 'package:billard_cfa/features/manage_club/domain/list_issued_invitations.dart';
import 'package:billard_cfa/features/manage_club/domain/revoke_invitation.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/club_world.dart';
import '../../../../support/domain_world.dart';

void main() {
  late ClubWorld world;
  const g1 = GroupId('g1');
  const g2 = GroupId('g2');
  const s1 = StudentId('s1');
  const s2 = StudentId('s2');
  const s3 = StudentId('s3');

  setUp(() async {
    world = ClubWorld();
    await world.seedLocalClub();
  });

  IssuedInvitations issued() =>
      IssuedInvitations(world.log, world.invitations, world.clock);

  ListInvitableStudents list() => ListInvitableStudents(
    world.local.students,
    world.local.groups,
    world.local.seasons,
    world.clock,
    world.scope,
    world.scope,
  );

  IssueInvitation issue() => IssueInvitation(
    world.invitations,
    world.directory,
    world.codes,
    issued(),
    world.local.students,
    world.local.groups,
    world.local.seasons,
    world.clock,
    world.scope,
    world.scope,
  );

  group('ListInvitableStudents', () {
    test('the director sees every student with a current group', () async {
      world.signIn(Role.director);
      final students = ok(await list()());
      expect(
        [
          for (final s in students)
            '${s.student.firstName}/${s.groups.single.name}',
        ],
        ['Léa/Mardi', 'Marc/Jeudi', 'Tom/Mardi'],
      );
    });

    test('a teacher only sees the students of their own groups', () async {
      world.signIn(
        Role.teacher,
        user: const UserId('u-sophie'),
        groupIds: [g1],
      );
      final students = ok(await list()());
      expect([for (final s in students) s.student.firstName], ['Léa', 'Tom']);
    });

    test('a teacher with no group sees nobody', () async {
      world.signIn(Role.teacher, user: const UserId('u-sophie'));
      expect(ok(await list()()), isEmpty);
    });

    test('a student without a current group is not invitable', () async {
      world.signIn(Role.director);
      await world.local.groups.delete(g2);
      final students = ok(await list()());
      expect([for (final s in students) s.student.firstName], ['Léa', 'Tom']);
    });

    test('a student, a parent and nobody are refused', () async {
      for (final role in [Role.student, Role.guardian]) {
        world.signIn(role, user: const UserId('u-x'));
        expect(codeOf(await list()()), InvariantCode.actionNotAllowed);
      }
    });
  });

  group('IssueInvitation', () {
    test('the director invites a teacher with groups for 48 hours', () async {
      world.signIn(Role.director);

      final invitation = ok(
        await issue()(role: Role.teacher, groupIds: {g1, g2}),
      );

      expect(invitation.code.value, 'TESTCODEAAAA');
      expect(invitation.role, Role.teacher);
      expect(invitation.groupIds, [g1, g2]);
      expect(invitation.expiresAt, DateTime(2026, 10, 14, 9, 30));
      final stored = world.doc('invitations/TESTCODEAAAA')!;
      expect(stored['clubId'], 'c1');
      expect(stored['role'], 'teacher');
      expect(stored['groupIds'], ['g1', 'g2']);
      expect(stored['studentIds'], isEmpty);
      expect(stored['createdBy'], 'u-director');
      expect(stored['used'], isFalse);
      expect(stored['expiresAt'], DateTime(2026, 10, 14, 9, 30));
    });

    test('the code is remembered on the device for the club', () async {
      world.signIn(Role.director);
      final invitation = ok(await issue()(role: Role.teacher));

      final entries = await world.log.read(world.scope.id!, ClubWorld.club);

      expect([for (final e in entries) e.code], [invitation.code]);
      expect(entries.single.role, Role.teacher);
    });

    test(
      'a parent invitation links the fiche, its groups, for 7 days',
      () async {
        world.signIn(Role.director);

        final invitation = ok(
          await issue()(role: Role.guardian, studentIds: {s1}),
        );

        expect(invitation.studentIds, [s1]);
        expect(invitation.groupIds, [g1]);
        expect(invitation.expiresAt, DateTime(2026, 10, 19, 9, 30));
      },
    );

    test(
      'a parent of two children gets both fiches and the groups of both',
      () async {
        world.signIn(Role.director);

        final invitation = ok(
          await issue()(role: Role.guardian, studentIds: {s1, s3}),
        );

        expect(invitation.studentIds, [s1, s3]);
        expect(invitation.groupIds, [g1, g2]);
      },
    );

    test(
      'the fiche is published on the server with the first name only',
      () async {
        world.signIn(Role.director);

        ok(await issue()(role: Role.guardian, studentIds: {s1}));

        final published = world.doc('clubs/c1/students/s1')!;
        expect(published['firstName'], 'Léa');
        expect(published['audience'], 'children');
        expect(published['groupIds'], ['g1']);
        expect(published.keys.toSet(), {
          'firstName',
          'audience',
          'groupIds',
          'createdAt',
        });
      },
    );

    test('a fiche already published is not rewritten', () async {
      world.store.seed('clubs/c1/students/s1', {
        'firstName': 'Déjà',
        'groupIds': ['g1'],
        'audience': 'children',
      });
      world.signIn(Role.director);

      ok(await issue()(role: Role.guardian, studentIds: {s1}));

      expect(world.doc('clubs/c1/students/s1')!['firstName'], 'Déjà');
    });

    test('a first name longer than the server accepts cannot exist (the '
        'directory still cuts one that arrives from older data)', () async {
      final student = (await world.local.students.byId(s1))!;

      expect(
        () => student.copyWith(firstName: 'é' * (maxFirstNameLength + 20)),
        throwsA(
          isA<InvariantViolation>().having(
            (v) => v.code,
            'code',
            InvariantCode.nameTooLong,
          ),
        ),
      );
      expect(
        student.copyWith(firstName: 'é' * maxFirstNameLength).firstName,
        hasLength(maxFirstNameLength),
      );
    });

    test('a student invitation needs the age confirmation', () async {
      world.signIn(Role.director);

      expect(
        codeOf(await issue()(role: Role.student, studentIds: {s1})),
        InvariantCode.ageConfirmationRequired,
      );
      expect(
        world.store.documents.keys.where((p) => p.startsWith('invitations')),
        isEmpty,
      );
      expect(world.doc('clubs/c1/students/s1'), isNull, reason: 'rien publié');

      final invitation = ok(
        await issue()(role: Role.student, studentIds: {s1}, ageConfirmed: true),
      );
      expect(invitation.role, Role.student);
    });

    test('a student invitation links exactly one student', () async {
      world.signIn(Role.director);
      for (final ids in [
        <StudentId>{},
        {s1, s2},
      ]) {
        expect(
          codeOf(
            await issue()(
              role: Role.student,
              studentIds: ids,
              ageConfirmed: true,
            ),
          ),
          InvariantCode.studentChoiceRequired,
          reason: '$ids',
        );
      }
    });

    test('a parent invitation links one to four students', () async {
      world.signIn(Role.director);
      expect(
        codeOf(await issue()(role: Role.guardian)),
        InvariantCode.studentChoiceRequired,
      );
      final many = {s1, s2, s3, const StudentId('s4'), const StudentId('s5')};
      expect(
        codeOf(await issue()(role: Role.guardian, studentIds: many)),
        InvariantCode.studentChoiceRequired,
      );
    });

    test('a student that is not in the list is refused', () async {
      world.signIn(Role.director);
      expect(
        codeOf(
          await issue()(
            role: Role.guardian,
            studentIds: {const StudentId('inconnu')},
          ),
        ),
        InvariantCode.actionNotAllowed,
      );
    });

    test(
      'a teacher invites a student or a parent of their own group',
      () async {
        world.signIn(
          Role.teacher,
          user: const UserId('u-sophie'),
          groupIds: [g1],
        );

        final invitation = ok(
          await issue()(role: Role.guardian, studentIds: {s1}),
        );

        expect(invitation.createdBy, const UserId('u-sophie'));
        expect(invitation.groupIds, [g1]);
        expect(world.doc('clubs/c1/students/s1')!['groupIds'], ['g1']);
      },
    );

    test('a teacher cannot invite a student of another group', () async {
      world.signIn(
        Role.teacher,
        user: const UserId('u-sophie'),
        groupIds: [g1],
      );

      expect(
        codeOf(await issue()(role: Role.guardian, studentIds: {s3})),
        InvariantCode.actionNotAllowed,
      );
      expect(world.doc('clubs/c1/students/s3'), isNull);
    });

    test('a teacher cannot invite a teacher nor a director', () async {
      world.signIn(
        Role.teacher,
        user: const UserId('u-sophie'),
        groupIds: [g1],
      );

      for (final role in [Role.teacher, Role.director, Role.admin]) {
        expect(
          codeOf(await issue()(role: role)),
          InvariantCode.actionNotAllowed,
          reason: role.name,
        );
      }
    });

    test('the director cannot invite a director from a club', () async {
      world.signIn(Role.director);
      expect(
        codeOf(await issue()(role: Role.director)),
        InvariantCode.actionNotAllowed,
      );
    });

    test('a student and a parent cannot invite', () async {
      for (final role in [Role.student, Role.guardian]) {
        world.signIn(role, user: const UserId('u-x'));
        expect(
          codeOf(await issue()(role: Role.guardian, studentIds: {s1})),
          InvariantCode.actionNotAllowed,
          reason: role.name,
        );
      }
    });

    test('each invitation gets its own code', () async {
      world.signIn(Role.director);
      final first = ok(await issue()(role: Role.teacher));
      final second = ok(await issue()(role: Role.teacher));
      expect(first.code, isNot(second.code));
    });

    test('an unreachable service leaves nothing behind', () async {
      world
        ..signIn(Role.director)
        ..store.failing = StoreFailureCode.unavailable;

      final result = await issue()(role: Role.teacher);

      expect(
        (err(result) as ServiceFailure).code,
        ServiceFailureCode.unavailable,
      );
      expect(await world.log.read(world.scope.id!, ClubWorld.club), isEmpty);
    });
  });

  group('ListIssuedInvitations and RevokeInvitation', () {
    ListIssuedInvitations statuses() =>
        ListIssuedInvitations(issued(), world.scope, world.scope);
    RevokeInvitation revoke() =>
        RevokeInvitation(issued(), world.scope, world.scope);

    test(
      'lists the invitations of this device, newest first, with their state',
      () async {
        world.signIn(Role.director);
        final teacher = ok(await issue()(role: Role.teacher));
        world.clock.advance(const Duration(hours: 1));
        final parent = ok(await issue()(role: Role.guardian, studentIds: {s1}));

        final entries = ok(await statuses()());

        expect(
          [for (final e in entries) e.entry.code],
          [parent.code, teacher.code],
        );
        expect(
          [for (final e in entries) e.status],
          [InvitationStatus.waiting, InvitationStatus.waiting],
        );
      },
    );

    test('shows an expired and a used invitation', () async {
      world.signIn(Role.director);
      final teacher = ok(await issue()(role: Role.teacher));
      final parent = ok(await issue()(role: Role.guardian, studentIds: {s1}));
      world.store.seed('invitations/${parent.code.value}', {
        ...world.doc('invitations/${parent.code.value}')!,
        'used': true,
        'usedBy': 'u-anne',
      });
      world.clock.advance(const Duration(days: 3));

      final entries = ok(await statuses()());

      expect(
        {for (final e in entries) e.entry.code: e.status},
        {
          parent.code: InvitationStatus.used,
          teacher.code: InvitationStatus.expired,
        },
      );
    });

    test('forgets an invitation that no longer exists on the server', () async {
      world.signIn(Role.director);
      final teacher = ok(await issue()(role: Role.teacher));
      world.store.remove('invitations/${teacher.code.value}');

      expect(ok(await statuses()()), isEmpty);
      expect(await world.log.read(world.scope.id!, ClubWorld.club), isEmpty);
    });

    test(
      'keeps the entry, with an unknown state, when the server is unreachable',
      () async {
        world.signIn(Role.director);
        final teacher = ok(await issue()(role: Role.teacher));
        world.store.failing = StoreFailureCode.unavailable;

        final entries = ok(await statuses()());

        expect(entries.single.entry.code, teacher.code);
        expect(entries.single.status, isNull);
        world.store.failing = null;
        expect(
          await world.log.read(world.scope.id!, ClubWorld.club),
          hasLength(1),
        );
      },
    );

    test('revoking deletes the invitation and forgets the code', () async {
      world.signIn(Role.director);
      final teacher = ok(await issue()(role: Role.teacher));

      ok(await revoke()(teacher.code));

      expect(world.doc('invitations/${teacher.code.value}'), isNull);
      expect(await world.log.read(world.scope.id!, ClubWorld.club), isEmpty);
    });

    test('a failed revocation keeps the code on the device', () async {
      world.signIn(Role.director);
      final teacher = ok(await issue()(role: Role.teacher));
      world.store.failing = StoreFailureCode.permissionDenied;

      final result = await revoke()(teacher.code);

      expect((err(result) as ServiceFailure).code, ServiceFailureCode.denied);
      world.store.failing = null;
      expect(
        await world.log.read(world.scope.id!, ClubWorld.club),
        hasLength(1),
      );
    });

    test(
      'a student and a parent have no invitations to list or revoke',
      () async {
        world.signIn(Role.student, user: const UserId('u-x'));
        expect(codeOf(await statuses()()), InvariantCode.actionNotAllowed);
        expect(
          codeOf(await revoke()(InvitationCode.tryParse('ABCDEFGHJKMN')!)),
          InvariantCode.actionNotAllowed,
        );
      },
    );
  });
}
