import 'package:billard_cfa/entities/invitation/data/key_value_invitation_log.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryKeyValueStore store;
  late KeyValueInvitationLog log;
  const alice = UserId('alice');
  const nice = ClubId('nice');
  const lyon = ClubId('lyon');

  IssuedInvitation issued(String code, {Role role = Role.teacher}) =>
      IssuedInvitation(
        code: InvitationCode.tryParse(code)!,
        role: role,
        createdAt: DateTime(2026, 10, 12, 9, 30),
        expiresAt: DateTime(2026, 10, 14, 9, 30),
      );

  setUp(() {
    store = InMemoryKeyValueStore();
    log = KeyValueInvitationLog(store);
  });

  test(
    'remembers invitations per account and per club, newest first',
    () async {
      await log.add(alice, nice, issued('AAAAAAAAAA'));
      await log.add(alice, nice, issued('BBBBBBBBBB', role: Role.guardian));
      await log.add(alice, lyon, issued('CCCCCCCCCC'));
      await log.add(const UserId('bob'), nice, issued('DDDDDDDDDD'));

      final inNice = await log.read(alice, nice);

      expect(
        [for (final e in inNice) e.code.value],
        ['BBBBBBBBBB', 'AAAAAAAAAA'],
      );
      expect(inNice.first.role, Role.guardian);
      expect(inNice.first.createdAt, DateTime(2026, 10, 12, 9, 30));
      expect(inNice.first.expiresAt, DateTime(2026, 10, 14, 9, 30));
      expect(
        [for (final e in await log.read(alice, lyon)) e.code.value],
        ['CCCCCCCCCC'],
      );
      expect(
        [
          for (final e in await log.read(const UserId('bob'), nice))
            e.code.value,
        ],
        ['DDDDDDDDDD'],
      );
    },
  );

  test('adding a code twice keeps one entry, at the front', () async {
    await log.add(alice, nice, issued('AAAAAAAAAA'));
    await log.add(alice, nice, issued('BBBBBBBBBB'));
    await log.add(alice, nice, issued('AAAAAAAAAA'));

    expect(
      [for (final e in await log.read(alice, nice)) e.code.value],
      ['AAAAAAAAAA', 'BBBBBBBBBB'],
    );
  });

  test('keeps the newest ${InvitationLog.maxEntries} entries', () async {
    String code(int n) =>
        'ABCDEFGHJ${String.fromCharCode(65 + n % 26)}'
        '${String.fromCharCode(65 + n ~/ 26)}';
    for (var i = 0; i < InvitationLog.maxEntries + 5; i++) {
      await log.add(alice, nice, issued(code(i)));
    }

    final entries = await log.read(alice, nice);

    expect(entries, hasLength(InvitationLog.maxEntries));
    expect(entries.first.code.value, code(InvitationLog.maxEntries + 4));
    expect(entries.last.code.value, code(5));
  });

  test('removes one code and forgets nothing else', () async {
    await log.add(alice, nice, issued('AAAAAAAAAA'));
    await log.add(alice, nice, issued('BBBBBBBBBB'));
    await log.add(alice, lyon, issued('CCCCCCCCCC'));

    await log.remove(alice, nice, InvitationCode.tryParse('AAAAAAAAAA')!);
    await log.remove(
      alice,
      const ClubId('rome'),
      InvitationCode.tryParse('AAAAAAAAAA')!,
    );

    expect(
      [for (final e in await log.read(alice, nice)) e.code.value],
      ['BBBBBBBBBB'],
    );
    expect(await log.read(alice, lyon), hasLength(1));
  });

  test('clear forgets everything of that account only', () async {
    await log.add(alice, nice, issued('AAAAAAAAAA'));
    await log.add(alice, lyon, issued('CCCCCCCCCC'));
    await log.add(const UserId('bob'), nice, issued('DDDDDDDDDD'));

    await log.clear(alice);

    expect(await log.read(alice, nice), isEmpty);
    expect(await log.read(alice, lyon), isEmpty);
    expect(await log.read(const UserId('bob'), nice), hasLength(1));
  });

  test('a club with nothing is empty', () async {
    expect(await log.read(alice, nice), isEmpty);
  });

  test('an unreadable stored value is ignored, never fatal', () async {
    await store.write(KeyValueInvitationLog.keyFor(alice), 'pas du json');
    expect(await log.read(alice, nice), isEmpty);
    await store.write(KeyValueInvitationLog.keyFor(alice), '[1,2]');
    expect(await log.read(alice, nice), isEmpty);
    await store.write(
      KeyValueInvitationLog.keyFor(alice),
      '{"nice":[{"code":"ABCDEFGHJK","role":"teacher",'
      '"createdAt":"2026-10-12T09:30:00.000",'
      '"expiresAt":"2026-10-14T09:30:00.000"},'
      '{"code":"court","role":"teacher","createdAt":"x","expiresAt":"y"},'
      '{"code":"ABCDEFGHJM","role":"wizard",'
      '"createdAt":"2026-10-12T09:30:00.000",'
      '"expiresAt":"2026-10-14T09:30:00.000"},'
      '12],"lyon":"x"}',
    );
    expect(
      [for (final e in await log.read(alice, nice)) e.code.value],
      ['ABCDEFGHJK'],
    );
    expect(await log.read(alice, lyon), isEmpty);
  });

  test('removing from a club with nothing changes nothing', () async {
    await log.remove(alice, nice, InvitationCode.tryParse('AAAAAAAAAA')!);
    expect(store.entries, isEmpty);
  });
}
