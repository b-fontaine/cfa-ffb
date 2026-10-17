import 'package:billard_cfa/entities/membership/data/in_memory_memberships_source.dart';
import 'package:billard_cfa/entities/membership/data/no_memberships_source.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const alice = UserId('alice');
  const nice = ClubMembership(
    clubId: ClubId('nice'),
    clubName: 'Club Nice',
    role: Role.director,
  );

  group('InMemoryMembershipsSource', () {
    test('returns what was granted, per account', () async {
      final source = InMemoryMembershipsSource()..grant(alice, nice);

      expect(await source.membershipsOf(alice), [nice]);
      expect(await source.membershipsOf(const UserId('bob')), isEmpty);
      expect(source.reads, 2);
    });

    test('revokeAll removes every club of the account', () async {
      final source = InMemoryMembershipsSource()
        ..grant(alice, nice)
        ..revokeAll(alice);

      expect(await source.membershipsOf(alice), isEmpty);
    });

    test('is unreadable on demand, as when offline', () async {
      final source = InMemoryMembershipsSource()..unavailable = true;

      await expectLater(
        source.membershipsOf(alice),
        throwsA(isA<MembershipsUnavailable>()),
      );
    });
  });

  test('before FB3 no account belongs to any club', () async {
    expect(await NoMembershipsSource().membershipsOf(alice), isEmpty);
  });

  test('MembershipsUnavailable prints its detail', () {
    expect(const MembershipsUnavailable('x').toString(), contains('x'));
  });
}
