import 'package:billard_cfa/entities/membership/data/store_member_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryDocumentStore store;
  late StoreMemberRepository members;
  const club = ClubId('c1');

  void member(
    String uid,
    String role,
    String name, {
    List<String> groups = const [],
    List<String> students = const [],
    String clubId = 'c1',
    Object? joined,
  }) => store.seed('clubs/$clubId/members/$uid', {
    'uid': uid,
    'role': role,
    'displayName': name,
    'groupIds': groups,
    'studentIds': students,
    'createdAt': ?joined,
  });

  setUp(() {
    store = InMemoryDocumentStore();
    members = StoreMemberRepository(store);
  });

  test(
    'lists the members of the club sorted by name, whatever the case',
    () async {
      member('u1', 'teacher', 'sophie', groups: ['g1']);
      member('u2', 'guardian', 'Anne', students: ['s1']);
      member('u3', 'director', 'Zoé');
      member('u9', 'teacher', 'Autre club', clubId: 'c2');

      final list = await members.membersOf(club);

      expect([for (final m in list) m.displayName], ['Anne', 'sophie', 'Zoé']);
      expect(list.first.role, Role.guardian);
      expect(list.first.uid, const UserId('u2'));
      expect(list.first.studentIds, [const StudentId('s1')]);
      expect(list[1].groupIds, [const GroupId('g1')]);
    },
  );

  test('reads the join date when there is one', () async {
    member('u1', 'teacher', 'A', joined: DateTime(2026, 10, 12));
    member('u2', 'teacher', 'B');
    final list = await members.membersOf(club);
    expect(list.first.joinedAt, DateTime(2026, 10, 12));
    expect(list.last.joinedAt, isNull);
  });

  test(
    'ignores a document with an unknown role, no name or a name out of bounds',
    () async {
      member('u1', 'wizard', 'A');
      store
        ..seed('clubs/c1/members/u2', {'role': 'teacher'})
        ..seed('clubs/c1/members/u3', {'role': 'teacher', 'displayName': ' '})
        ..seed('clubs/c1/members/u4', {
          'role': 'teacher',
          'displayName': 'é' * 99,
        });
      member('u5', 'teacher', 'Ok');

      expect(
        [for (final m in await members.membersOf(club)) m.displayName],
        ['Ok'],
      );
    },
  );

  test('removing deletes the member document only', () async {
    member('u1', 'teacher', 'A');
    member('u2', 'teacher', 'B');

    await members.remove(club, const UserId('u1'));

    expect(store.read('clubs/c1/members/u1'), isNull);
    expect(store.read('clubs/c1/members/u2'), isNotNull);
  });

  test('failures become ServiceFailure', () async {
    store.failing = StoreFailureCode.permissionDenied;
    await expectLater(
      members.membersOf(club),
      throwsA(
        isA<ServiceFailure>().having(
          (e) => e.code,
          'code',
          ServiceFailureCode.denied,
        ),
      ),
    );
    await expectLater(
      members.remove(club, const UserId('u1')),
      throwsA(isA<ServiceFailure>()),
    );
  });
}
