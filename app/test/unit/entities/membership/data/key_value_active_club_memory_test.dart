import 'package:billard_cfa/entities/membership/data/key_value_active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const alice = UserId('alice');
  const bob = UserId('bob');
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

  late InMemoryKeyValueStore store;
  late KeyValueActiveClubMemory memory;

  setUp(() {
    store = InMemoryKeyValueStore();
    memory = KeyValueActiveClubMemory(store);
  });

  test('reads back the club written for the same account', () async {
    await memory.write(alice, nice);

    expect(await memory.read(alice), nice);
  });

  test('the key carries the account: another user reads nothing', () async {
    await memory.write(alice, nice);

    expect(await memory.read(bob), isNull);
    expect(store.entries.keys, ['active_club.alice']);
  });

  test('writing again replaces the previous club', () async {
    await memory.write(alice, nice);
    await memory.write(alice, lyon);

    expect(await memory.read(alice), lyon);
  });

  test('clear forgets the club of that account only', () async {
    await memory.write(alice, nice);
    await memory.write(bob, lyon);

    await memory.clear(alice);

    expect(await memory.read(alice), isNull);
    expect(await memory.read(bob), lyon);
  });

  test('an unreadable stored value is ignored, never fatal', () async {
    final key = KeyValueActiveClubMemory.keyFor(alice);
    for (final raw in [
      'not json',
      '[]',
      '{"club": "", "name": "x", "role": "teacher"}',
      '{"club": "c", "name": "x", "role": "owner"}',
      '{"club": "c", "role": "teacher"}',
      '{"club": 3, "name": "x", "role": "teacher"}',
    ]) {
      await store.write(key, raw);
      expect(await memory.read(alice), isNull, reason: raw);
    }
  });
}
