import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // La table de l'ADR 0024 (matrice des droits), écrite ligne à ligne.
  const expected = <Role, Set<Capability>>{
    Role.student: {Capability.viewChildren},
    Role.guardian: {Capability.viewChildren},
    Role.teacher: {
      Capability.animate,
      Capability.openClub,
      Capability.inviteFamilies,
      Capability.importBackup,
    },
    Role.director: {
      Capability.animate,
      Capability.manageSettings,
      Capability.closeSeason,
      Capability.eraseStudent,
      Capability.openClub,
      Capability.manageClub,
      Capability.inviteTeachers,
      Capability.inviteFamilies,
      Capability.importBackup,
    },
    Role.admin: {
      Capability.animate,
      Capability.manageSettings,
      Capability.closeSeason,
      Capability.eraseStudent,
      Capability.openClub,
      Capability.manageClub,
      Capability.inviteTeachers,
      Capability.inviteFamilies,
      Capability.administer,
      Capability.importBackup,
    },
  };

  for (final role in Role.values) {
    test('${role.name} has exactly its capabilities', () {
      expect(role.capabilities, expected[role]);
      for (final capability in Capability.values) {
        expect(
          role.can(capability),
          expected[role]!.contains(capability),
          reason: '${role.name} / ${capability.name}',
        );
      }
    });
  }

  test('only the roles that run sessions animate', () {
    expect(
      [
        for (final r in Role.values)
          if (r.animates) r,
      ],
      [Role.teacher, Role.director, Role.admin],
    );
  });

  test('only the administrator administers', () {
    expect(
      [
        for (final r in Role.values)
          if (r.can(Capability.administer)) r,
      ],
      [Role.admin],
    );
  });

  test('who can invite whom, never a director from a club', () {
    expect(Role.student.invitableRoles, isEmpty);
    expect(Role.guardian.invitableRoles, isEmpty);
    expect(Role.teacher.invitableRoles, [Role.student, Role.guardian]);
    expect(Role.director.invitableRoles, [
      Role.teacher,
      Role.student,
      Role.guardian,
    ]);
    expect(Role.admin.invitableRoles, Role.director.invitableRoles);
  });
}
