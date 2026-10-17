import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/features/select_club/domain/resolve_active_club.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nice = ClubMembership(
    clubId: ClubId('nice'),
    clubName: 'Club Nice',
    role: Role.director,
  );
  const lyon = ClubMembership(
    clubId: ClubId('lyon'),
    clubName: 'Club Lyon',
    role: Role.teacher,
  );

  test('no club at all', () {
    expect(resolveActiveClub(memberships: const []), isA<NoClub>());
  });

  test('a remembered club does not create a club out of nothing', () {
    expect(
      resolveActiveClub(memberships: const [], remembered: nice),
      isA<NoClub>(),
    );
  });

  test('a single club is the active club', () {
    final result = resolveActiveClub(memberships: const [nice]);

    expect(result, isA<ChosenClub>().having((c) => c.club, 'club', nice));
  });

  test('several clubs and none remembered: the user chooses', () {
    expect(
      resolveActiveClub(memberships: const [nice, lyon]),
      isA<MustChooseClub>(),
    );
  });

  test('the remembered club wins among several', () {
    final result = resolveActiveClub(
      memberships: const [nice, lyon],
      remembered: lyon,
    );

    expect(result, isA<ChosenClub>().having((c) => c.club, 'club', lyon));
  });

  test('a remembered club that is gone is ignored', () {
    final result = resolveActiveClub(
      memberships: const [nice, lyon],
      remembered: const ClubMembership(
        clubId: ClubId('paris'),
        clubName: 'Club Paris',
        role: Role.guardian,
      ),
    );

    expect(result, isA<MustChooseClub>());
  });

  test('the current role replaces the remembered one', () {
    final result = resolveActiveClub(
      memberships: const [nice],
      remembered: const ClubMembership(
        clubId: ClubId('nice'),
        clubName: 'Old name',
        role: Role.teacher,
      ),
    );

    expect(result, isA<ChosenClub>().having((c) => c.club, 'club', nice));
  });
}
