import 'package:billard_cfa/features/manage_club/domain/list_invitable_groups.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/club_world.dart';
import '../../../../support/domain_world.dart';

void main() {
  late ClubWorld world;
  late ListInvitableGroups list;

  setUp(() async {
    world = ClubWorld();
    await world.seedLocalClub();
    list = ListInvitableGroups(
      world.local.groups,
      world.local.seasons,
      world.clock,
      world.scope,
      world.scope,
    );
  });

  test('the director sees the groups of the current season, by name', () async {
    world.signIn(Role.director);

    final groups = ok(await list());

    expect([for (final g in groups) g.name], ['Jeudi', 'Mardi']);
  });

  test('a group of a closed season is not proposed', () async {
    world.signIn(Role.director);
    final season = (await world.local.seasons.all()).single;
    await world.local.seasons.save(
      season.copyWith(closedOn: DateTime(2026, 10, 12)),
    );

    expect(ok(await list()), isEmpty);
  });

  test('a teacher cannot invite teachers: no group list', () async {
    world.signIn(Role.teacher, user: const UserId('u-sophie'));
    expect(codeOf(await list()), InvariantCode.actionNotAllowed);
  });
}
