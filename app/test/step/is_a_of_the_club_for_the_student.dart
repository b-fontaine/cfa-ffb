import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'lea@example.org'} is a {'student'} of the club {'Test club'} for
/// the student {'Léa'}
///
/// Le compte (créé, adresse vérifiée) est élève ou parent de cette fiche ; ses
/// groupes sont ceux où l'élève est membre aujourd'hui.
Future<void> isAOfTheClubForTheStudent(
  WidgetTester tester,
  String email,
  String role,
  String club,
  String studentName,
) async {
  await UiWorld.prepare(tester);
  final account =
      UiWorld.auth.accountOf(email) ??
      UiWorld.auth.seed(email: email, password: 'correct-horse-battery');
  final student = await UiWorld.studentNamed(studentName);
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
          if (group.isMemberOn(student.id, today)) group.id,
      ],
      studentIds: [student.id],
    ),
    displayName: email.split('@').first,
  );
}
