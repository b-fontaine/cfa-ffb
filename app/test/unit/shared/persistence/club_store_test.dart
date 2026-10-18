import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/firestore_world.dart';

void main() {
  group('ClubPaths', () {
    const paths = ClubPaths(ClubId('c1'));

    test('names the collections of firestore.rules, inside the club', () {
      expect(paths.settings, 'clubs/c1/settings/main');
      expect(paths.students, 'clubs/c1/students');
      expect(paths.student(const StudentId('s1')), 'clubs/c1/students/s1');
      expect(paths.groups, 'clubs/c1/groups');
      expect(paths.group(const GroupId('g1')), 'clubs/c1/groups/g1');
      expect(paths.memberships, 'clubs/c1/memberships');
    });

    test('a membership id names group, student and the exact start', () {
      expect(
        paths.membership(
          const GroupId('g1'),
          const StudentId('s1'),
          DateTime(2026, 9),
        ),
        'clubs/c1/memberships/g1_s1_2026-09-01T00:00:00.000',
      );
      expect(
        paths.membership(
          const GroupId('g1'),
          const StudentId('s1'),
          DateTime.utc(2026, 9),
        ),
        'clubs/c1/memberships/g1_s1_2026-09-01T00:00:00.000Z',
      );
    });

    test('the same student starting the same day in two groups differs', () {
      final from = DateTime(2026, 9);
      expect(
        paths.membership(const GroupId('g1'), const StudentId('s1'), from),
        isNot(
          paths.membership(const GroupId('g2'), const StudentId('s1'), from),
        ),
      );
    });
  });

  group('ClubStore', () {
    late FirestoreWorld world;
    setUp(() => world = FirestoreWorld());

    test('without an active club, access is denied, never a guessed path', () {
      expect(
        () => world.club.paths,
        throwsA(
          isA<ServiceFailure>()
              .having((f) => f.code, 'code', ServiceFailureCode.denied)
              .having((f) => f.detail, 'detail', 'no-active-club'),
        ),
      );
    });

    test('resolves the club at every call, not at construction', () {
      world.act('c1', Role.director);
      expect(world.club.paths.root, 'clubs/c1');

      world.act('c2', Role.teacher, groups: ['g1']);

      expect(world.club.paths.root, 'clubs/c2');
      expect(world.club.role, Role.teacher);
      expect(world.club.groupIds, [const GroupId('g1')]);
      world.scope.deactivateClub();
      expect(() => world.club.paths, throwsA(isA<ServiceFailure>()));
    });

    test('directors and administrators manage the club, nobody else', () {
      for (final (role, manages) in [
        (Role.director, true),
        (Role.admin, true),
        (Role.teacher, false),
        (Role.guardian, false),
        (Role.student, false),
      ]) {
        world.act('c1', role);
        expect(world.club.manages, manages, reason: role.name);
      }
    });

    test('commit sends batches of at most 500 writes, in order', () async {
      world.act('c1', Role.director);
      final ops = [
        for (var i = 0; i < 1203; i++) SetOp('clubs/c1/students/s$i', {'n': i}),
      ];

      await world.club.commit(ops);

      expect(world.documents.commits, 3);
      expect(world.documents.documents, hasLength(1203));
      expect(maxBatchWrites, 500);
    });

    test('commit of nothing writes nothing', () async {
      await world.club.commit(const []);

      expect(world.documents.commits, 0);
    });
  });
}
