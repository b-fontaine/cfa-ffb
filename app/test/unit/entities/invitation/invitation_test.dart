import 'package:billard_cfa/entities/invitation/domain/invitation.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 12, 9, 30);
  final code = InvitationCode.tryParse('ABCDEFGHJKMN')!;
  const club = ClubId('c1');
  const issuer = UserId('u-dir');

  Invitation make({
    Role role = Role.teacher,
    List<GroupId> groups = const [],
    List<StudentId> students = const [],
    DateTime? expires,
    DateTime? created,
  }) => Invitation(
    code: code,
    clubId: club,
    role: role,
    createdBy: issuer,
    createdAt: created ?? now,
    expiresAt: expires ?? now.add(const Duration(hours: 48)),
    groupIds: groups,
    studentIds: students,
  );

  InvariantCode? refusedWith(Invitation Function() build) {
    try {
      build();
    } on InvariantViolation catch (e) {
      return e.code;
    }
    return null;
  }

  group('InvitationPolicy.validityOf', () {
    test('48 hours for the roles that are more powerful, 7 days otherwise', () {
      expect(
        InvitationPolicy.validityOf(Role.teacher),
        const Duration(hours: 48),
      );
      expect(
        InvitationPolicy.validityOf(Role.director),
        const Duration(hours: 48),
      );
      expect(
        InvitationPolicy.validityOf(Role.student),
        const Duration(days: 7),
      );
      expect(
        InvitationPolicy.validityOf(Role.guardian),
        const Duration(days: 7),
      );
    });
  });

  group('InvitationPolicy.canIssue', () {
    test('matches the matrix of the ADR', () {
      const allowed = {
        (Role.teacher, Role.student),
        (Role.teacher, Role.guardian),
        (Role.director, Role.teacher),
        (Role.director, Role.student),
        (Role.director, Role.guardian),
        (Role.admin, Role.teacher),
        (Role.admin, Role.student),
        (Role.admin, Role.guardian),
        (Role.admin, Role.director),
      };
      for (final issuer in Role.values) {
        for (final target in Role.values) {
          expect(
            InvitationPolicy.canIssue(issuer, target),
            allowed.contains((issuer, target)),
            reason: '${issuer.name} invites ${target.name}',
          );
        }
      }
    });
  });

  group('Invitation shape', () {
    test('a teacher invitation may have groups, never students', () {
      expect(make(groups: const [GroupId('g1')]).groupIds, hasLength(1));
      expect(make().groupIds, isEmpty);
      expect(
        refusedWith(() => make(students: const [StudentId('s1')])),
        InvariantCode.invalidInvitation,
      );
    });

    test('a director invitation has neither groups nor students', () {
      expect(make(role: Role.director).role, Role.director);
      expect(
        refusedWith(
          () => make(role: Role.director, groups: const [GroupId('g1')]),
        ),
        InvariantCode.invalidInvitation,
      );
      expect(
        refusedWith(
          () => make(role: Role.director, students: const [StudentId('s1')]),
        ),
        InvariantCode.invalidInvitation,
      );
    });

    test('a student invitation has one student and at least one group', () {
      const one = [StudentId('s1')];
      const group = [GroupId('g1')];
      expect(
        make(role: Role.student, students: one, groups: group).role,
        Role.student,
      );
      expect(
        refusedWith(() => make(role: Role.student, groups: group)),
        InvariantCode.invalidInvitation,
      );
      expect(
        refusedWith(
          () => make(
            role: Role.student,
            students: [...one, const StudentId('s2')],
            groups: group,
          ),
        ),
        InvariantCode.invalidInvitation,
      );
      expect(
        refusedWith(() => make(role: Role.student, students: one)),
        InvariantCode.invalidInvitation,
      );
    });

    test('a parent invitation has one to four students and a group', () {
      const group = [GroupId('g1')];
      List<StudentId> students(int n) => [
        for (var i = 0; i < n; i++) StudentId('s$i'),
      ];
      expect(
        make(
          role: Role.guardian,
          students: students(1),
          groups: group,
        ).studentIds,
        hasLength(1),
      );
      expect(
        make(
          role: Role.guardian,
          students: students(4),
          groups: group,
        ).studentIds,
        hasLength(4),
      );
      expect(
        refusedWith(() => make(role: Role.guardian, groups: group)),
        InvariantCode.invalidInvitation,
      );
      expect(
        refusedWith(
          () => make(role: Role.guardian, students: students(5), groups: group),
        ),
        InvariantCode.invalidInvitation,
      );
      expect(
        refusedWith(() => make(role: Role.guardian, students: students(1))),
        InvariantCode.invalidInvitation,
      );
    });

    test('nobody is invited as an administrator', () {
      expect(
        refusedWith(() => make(role: Role.admin)),
        InvariantCode.invalidInvitation,
      );
    });

    test('it expires after it was created', () {
      expect(
        refusedWith(() => make(expires: now)),
        InvariantCode.invalidInvitation,
      );
      expect(
        refusedWith(
          () => make(expires: now.subtract(const Duration(hours: 1))),
        ),
        InvariantCode.invalidInvitation,
      );
    });
  });

  group('Invitation.issue', () {
    test('stamps the issuer, the date and the validity of the role', () {
      final invitation = Invitation.issue(
        code: code,
        issuer: Role.director,
        issuerId: issuer,
        clubId: club,
        role: Role.teacher,
        now: now,
        groupIds: const [GroupId('g1')],
      );
      expect(invitation.createdBy, issuer);
      expect(invitation.createdAt, now);
      expect(invitation.expiresAt, now.add(const Duration(hours: 48)));
      expect(invitation.used, isFalse);
      expect(invitation.usedBy, isNull);
    });

    test('refuses a role the issuer cannot invite', () {
      expect(
        refusedWith(
          () => Invitation.issue(
            code: code,
            issuer: Role.teacher,
            issuerId: issuer,
            clubId: club,
            role: Role.teacher,
            now: now,
          ),
        ),
        InvariantCode.actionNotAllowed,
      );
    });

    test('an administrator invites a director', () {
      final invitation = Invitation.issue(
        code: code,
        issuer: Role.admin,
        issuerId: const UserId('u-root'),
        clubId: club,
        role: Role.director,
        now: now,
      );
      expect(invitation.role, Role.director);
    });
  });

  group('Invitation.statusAt', () {
    test('is waiting until it expires, expired from then on', () {
      final invitation = make();
      expect(invitation.statusAt(now), InvitationStatus.waiting);
      expect(
        invitation.statusAt(
          invitation.expiresAt.subtract(const Duration(seconds: 1)),
        ),
        InvitationStatus.waiting,
      );
      expect(
        invitation.statusAt(invitation.expiresAt),
        InvitationStatus.expired,
      );
    });

    test('used wins over expired', () {
      final used = make().copyWith(used: true, usedBy: const UserId('u-x'));
      expect(used.statusAt(now), InvitationStatus.used);
      expect(
        used.statusAt(now.add(const Duration(days: 30))),
        InvitationStatus.used,
      );
    });
  });
}
