import 'package:billard_cfa/entities/membership/data/key_value_active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/features/select_club/domain/choose_club.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/auth_rig.dart';

void main() {
  const alice = UserId('alice');
  const lyon = ClubMembership(
    clubId: ClubId('lyon'),
    clubName: 'Club Lyon',
    role: Role.teacher,
  );

  late InMemoryKeyValueStore store;
  late ActiveClubMemory memory;
  late FakeClubSwitchGuard guard;
  late ChooseClub choose;

  setUp(() {
    store = InMemoryKeyValueStore();
    memory = KeyValueActiveClubMemory(store);
    guard = FakeClubSwitchGuard();
    choose = ChooseClub(memory, guard);
  });

  test('retains the chosen club for the account', () async {
    await choose(user: alice, club: lyon, switching: false);

    expect(await memory.read(alice), lyon);
  });

  test('switching is allowed when nothing is in progress', () async {
    await choose(user: alice, club: lyon, switching: true);

    expect(await memory.read(alice), lyon);
  });

  test(
    'switching is refused while the guard blocks, nothing is written',
    () async {
      guard.isBlocked = true;

      await expectLater(
        choose(user: alice, club: lyon, switching: true),
        throwsA(isA<ClubSwitchBlocked>()),
      );
      expect(await memory.read(alice), isNull);
    },
  );

  test(
    'the first choice has nothing to lose: the guard does not apply',
    () async {
      guard.isBlocked = true;

      await choose(user: alice, club: lyon, switching: false);

      expect(await memory.read(alice), lyon);
    },
  );

  test('ClubSwitchBlocked prints its name', () {
    expect(const ClubSwitchBlocked().toString(), 'ClubSwitchBlocked()');
  });
}
