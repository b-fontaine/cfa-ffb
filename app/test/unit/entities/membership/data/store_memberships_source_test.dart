import 'package:billard_cfa/entities/membership/data/store_memberships_source.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryDocumentStore store;
  late StoreMembershipsSource source;
  const alice = UserId('alice');

  void club(String id, String name) =>
      store.seed('clubs/$id', {'name': name, 'createdAt': DateTime(2026)});

  void member(
    String clubId,
    String uid,
    String role, {
    List<String> groups = const [],
    List<String> students = const [],
  }) => store.seed('clubs/$clubId/members/$uid', {
    'uid': uid,
    'role': role,
    'displayName': uid,
    'groupIds': groups,
    'studentIds': students,
  });

  setUp(() {
    store = InMemoryDocumentStore();
    source = StoreMembershipsSource(store);
  });

  test('a compte without member belongs to no club', () async {
    club('nice', 'Club Nice');
    member('nice', 'bob', 'teacher');

    expect(await source.membershipsOf(alice), isEmpty);
    expect(await source.isAdmin(alice), isFalse);
  });

  test('reads the role, the name and the scope of each club', () async {
    club('nice', 'Club Nice');
    club('lyon', 'Club Lyon');
    member('nice', 'alice', 'teacher', groups: ['g1', 'g2']);
    member('lyon', 'alice', 'guardian', groups: ['g9'], students: ['s1']);
    member('nice', 'bob', 'director');

    final clubs = await source.membershipsOf(alice);

    expect(clubs, hasLength(2));
    final nice = clubs.firstWhere((c) => c.clubId == const ClubId('nice'));
    expect(nice.clubName, 'Club Nice');
    expect(nice.role, Role.teacher);
    expect(nice.groupIds, [const GroupId('g1'), const GroupId('g2')]);
    expect(nice.studentIds, isEmpty);
    final lyon = clubs.firstWhere((c) => c.clubId == const ClubId('lyon'));
    expect(lyon.role, Role.guardian);
    expect(lyon.studentIds, [const StudentId('s1')]);
  });

  test(
    'ignores a member with an unknown role, an admin role or no club',
    () async {
      club('nice', 'Club Nice');
      member('nice', 'alice', 'wizard');
      member('lyon', 'alice', 'director'); // le club « lyon » n'existe pas
      member('rome', 'alice', 'admin');
      club('rome', 'Club Rome');

      expect(await source.membershipsOf(alice), isEmpty);
    },
  );

  test('ignores a club document without a name', () async {
    store.seed('clubs/nice', {'createdAt': DateTime(2026)});
    member('nice', 'alice', 'teacher');

    expect(await source.membershipsOf(alice), isEmpty);
  });

  test('an administrator sees every club, as admin unless a member', () async {
    club('nice', 'Club Nice');
    club('lyon', 'Club Lyon');
    store.seed('admins/alice', {});
    member('lyon', 'alice', 'director');

    final clubs = await source.membershipsOf(alice);

    expect(await source.isAdmin(alice), isTrue);
    expect(clubs, hasLength(2));
    expect(
      clubs.firstWhere((c) => c.clubId == const ClubId('nice')).role,
      Role.admin,
    );
    // Le rôle de club l'emporte sur celui d'administrateur (ordre des règles).
    expect(
      clubs.firstWhere((c) => c.clubId == const ClubId('lyon')).role,
      Role.director,
    );
  });

  test(
    'an administrator with no club at all gets an empty list but is admin',
    () async {
      store.seed('admins/alice', {});

      expect(await source.membershipsOf(alice), isEmpty);
      expect(await source.isAdmin(alice), isTrue);
    },
  );

  test('a non-administrator never sees clubs they are no member of', () async {
    club('nice', 'Club Nice');
    club('lyon', 'Club Lyon');
    member('lyon', 'alice', 'student');

    final clubs = await source.membershipsOf(alice);

    expect([for (final c in clubs) c.clubId.value], ['lyon']);
  });

  test(
    'an unreachable service is MembershipsUnavailable, never a crash',
    () async {
      store.failing = StoreFailureCode.unavailable;

      await expectLater(
        source.membershipsOf(alice),
        throwsA(isA<MembershipsUnavailable>()),
      );
      await expectLater(
        source.isAdmin(alice),
        throwsA(isA<MembershipsUnavailable>()),
      );
    },
  );

  for (final (code, label) in [
    (StoreFailureCode.permissionDenied, 'a rule refusal'),
    (StoreFailureCode.failedPrecondition, 'a missing index'),
  ]) {
    test('$label is MembershipsDenied, not a network failure', () async {
      store.failing = code;

      await expectLater(
        source.membershipsOf(alice),
        throwsA(isA<MembershipsDenied>()),
      );
      await expectLater(
        source.isAdmin(alice),
        throwsA(isA<MembershipsDenied>()),
      );
    });
  }

  test('any other service error stays MembershipsUnavailable', () async {
    store.failing = StoreFailureCode.other;

    await expectLater(
      source.membershipsOf(alice),
      throwsA(isA<MembershipsUnavailable>()),
    );
  });

  test(
    'uses one group query, one read per club and one read of admins',
    () async {
      club('nice', 'Club Nice');
      member('nice', 'alice', 'teacher');

      await source.membershipsOf(alice);

      expect(store.reads, 3);
    },
  );

  test('MembershipsUnavailable prints its detail', () {
    expect(const MembershipsUnavailable('x').toString(), contains('x'));
  });

  test('a ClubMembership defaults to no group and no student', () {
    const bare = ClubMembership(
      clubId: ClubId('nice'),
      clubName: 'Club Nice',
      role: Role.director,
    );
    expect(bare.groupIds, isEmpty);
    expect(bare.studentIds, isEmpty);
  });
}
