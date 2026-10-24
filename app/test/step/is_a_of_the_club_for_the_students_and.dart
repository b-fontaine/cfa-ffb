import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'anne@example.org'} is a {'guardian'} of the club {'Test club'}
/// for the students {'Léa'} and {'Tom'}
///
/// Le compte (créé, adresse vérifiée) est lié aux deux fiches ; ses groupes
/// sont ceux de ces élèves aujourd'hui.
Future<void> isAOfTheClubForTheStudentsAnd(
  WidgetTester tester,
  String email,
  String role,
  String club,
  String first,
  String second,
) async {
  await UiWorld.prepare(tester);
  final account =
      UiWorld.auth.accountOf(email) ??
      UiWorld.auth.seed(email: email, password: 'correct-horse-battery');
  final students = [
    await UiWorld.studentNamed(first),
    await UiWorld.studentNamed(second),
  ];
  final today = DateTime(
    UiWorld.today.year,
    UiWorld.today.month,
    UiWorld.today.day,
  );
  final groups = await getIt<GroupRepository>().all();
  UiWorld.memberships.grant(
    account.id,
    ClubMembership(
      clubId: UiWorld.clubIdOf(club),
      clubName: club,
      role: UiWorld.role(role),
      groupIds: [
        for (final group in groups)
          if (students.any((student) => group.isMemberOn(student.id, today)))
            group.id,
      ],
      studentIds: [for (final student in students) student.id],
    ),
    displayName: email.split('@').first,
  );
}
