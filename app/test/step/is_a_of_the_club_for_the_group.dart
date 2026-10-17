import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'sophie@example.org'} is a {'teacher'} of the club {'Test club'}
/// for the group {'Children group'}
///
/// Le compte (créé, adresse vérifiée) est membre du club avec ce rôle et ce
/// groupe dans son périmètre ; son nom affiché est le début de son adresse.
Future<void> isAOfTheClubForTheGroup(
  WidgetTester tester,
  String email,
  String role,
  String club,
  String groupName,
) async {
  await UiWorld.prepare(tester);
  final account =
      UiWorld.auth.accountOf(email) ??
      UiWorld.auth.seed(email: email, password: 'correct-horse-battery');
  final groups = await getIt<GroupRepository>().all();
  final group = groups.firstWhere((g) => g.name == groupName);
  UiWorld.memberships.grant(
    account.id,
    ClubMembership(
      clubId: UiWorld.clubIdOf(club),
      clubName: club,
      role: UiWorld.role(role),
      groupIds: [group.id],
    ),
    displayName: email.split('@').first,
  );
}
