import 'dart:async';

import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/connectivity_status.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_paths.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/firestore_world.dart';
import '../../../support/stream_log.dart';

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

    group('watches', () {
      test('follow the documents of the active club', () async {
        world.act('c1', Role.director);
        final log = StreamLog(world.club.watchCollection('clubs/c1/students'));
        await log.settle();

        await world.club.commit([
          const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
        ]);
        await log.settle();

        expect([for (final u in log.values) u.documents.length], [0, 1]);
        await log.cancel();
      });

      test(
        'end with an error, and release the source, when the club changes',
        () async {
          world.act('c1', Role.director);
          final log = StreamLog(
            world.club.watchCollection('clubs/c1/students'),
          );
          await log.settle();
          expect(world.documents.activeWatchers, 1);

          world.act('c2', Role.director);
          world.documents.seed('clubs/c1/students/s1', {'firstName': 'Léa'});
          await log.settle();

          expect(log.values, hasLength(1));
          expect(
            log.errors.single,
            isA<StoreFailure>().having(
              (e) => e.code,
              'code',
              StoreFailureCode.permissionDenied,
            ),
          );
          expect(log.done, isTrue);
          expect(world.documents.activeWatchers, 0);
        },
      );

      test(
        'end with an error when the role changes in the same club',
        () async {
          world.act('c1', Role.teacher, groups: ['g1']);
          final log = StreamLog(
            world.club.watchQuery(
              'clubs/c1/records',
              const FieldEquals('groupId', 'g1'),
            ),
          );
          await log.settle();

          world.act('c1', Role.guardian, students: ['s1']);
          world.documents.seed('clubs/c1/records/r1', {'groupId': 'g1'});
          await log.settle();

          expect(log.errors, hasLength(1));
          expect(log.done, isTrue);
          expect(world.documents.activeWatchers, 0);
        },
      );

      test('end with an error when the session closes', () async {
        world.act('c1', Role.director);
        final log = StreamLog(
          world.club.watchDocument('clubs/c1/settings/main'),
        );
        await log.settle();

        world.scope.deactivateClub();
        world.documents.seed('clubs/c1/settings/main', {'a': 1});
        await log.settle();

        expect(log.errors, hasLength(1));
        expect(world.documents.activeWatchers, 0);
      });

      test('release the source at once when the scope changes, without any '
          'event to wake them', () async {
        world.act('c1', Role.director);
        final log = StreamLog(world.club.watchCollection('clubs/c1/students'));
        await log.settle();
        expect(world.documents.activeWatchers, 1);

        world.scope.deactivateClub();

        expect(world.documents.activeWatchers, 0);
        await log.settle();
        expect(log.errors, hasLength(1));
        expect(log.done, isTrue);
      });

      test('release at once on a change of club, role or groups', () async {
        for (final change in <void Function()>[
          () => world.act('c2', Role.teacher, groups: ['g1']),
          () => world.act('c1', Role.guardian, students: ['s1']),
          () => world.act('c1', Role.teacher, groups: ['g1', 'g2']),
        ]) {
          world.act('c1', Role.teacher, groups: ['g1']);
          final log = StreamLog(
            world.club.watchDocument('clubs/c1/students/s1'),
          );
          await log.settle();

          change();

          expect(world.documents.activeWatchers, 0);
          await log.settle();
        }
      });

      test('the same groups and students read in another order keep the '
          'watch open', () async {
        world.act(
          'c1',
          Role.guardian,
          groups: ['g1', 'g2'],
          students: ['s1', 's2'],
        );
        final log = StreamLog(world.club.watchDocument('clubs/c1/students/s1'));
        await log.settle();

        world.act(
          'c1',
          Role.guardian,
          groups: ['g2', 'g1'],
          students: ['s2', 's1'],
        );
        world.documents.seed('clubs/c1/students/s1', {'firstName': 'Léa'});
        await log.settle();

        expect(world.documents.activeWatchers, 1);
        expect(log.errors, isEmpty);
        expect(log.values, hasLength(2));
        await log.cancel();
      });

      test('keep delivering while the scope stays the same', () async {
        world.act('c1', Role.teacher, groups: ['g1']);
        final log = StreamLog(world.club.watchDocument('clubs/c1/students/s1'));
        await log.settle();

        world.act('c1', Role.teacher, groups: ['g1']);
        world.documents.seed('clubs/c1/students/s1', {'firstName': 'Léa'});
        await log.settle();

        expect(log.errors, isEmpty);
        expect(log.values, hasLength(2));
        await log.cancel();
      });
    });
  });

  group('ClubStore sends (FB5b : jamais bloquant hors ligne)', () {
    late FirestoreWorld world;
    late _SlowStore server;
    late SendTracker sends;
    late InMemoryConnectivityStatus network;
    late ClubStore club;

    setUp(() {
      server = _SlowStore();
      sends = SendTracker(InMemoryPendingWritesProbe());
      network = InMemoryConnectivityStatus();
      world = FirestoreWorld();
      club = ClubStore(
        server,
        world.scope,
        sends: sends,
        network: network,
        ackGrace: const Duration(milliseconds: 40),
      );
      world.act('c1', Role.director);
    });

    const write = [
      SetOp('clubs/c1/students/s1', {'n': 1}),
    ];

    test(
      'an acknowledged write returns once the server has answered',
      () async {
        await club.commit(write);

        expect(server.read('clubs/c1/students/s1'), {'n': 1});
        expect(sends.pending, 0);
      },
    );

    test('a write the server does not acknowledge returns after the grace '
        'and is followed by the send tracker', () async {
      server.hold();

      await club.commit(write);

      expect(sends.pending, 1);
      server.release();
      await pumpEventQueue();
      expect(sends.pending, 0);
      expect(sends.hasFailure, isFalse);
    });

    test('with the network known to be down it does not even wait', () async {
      server.hold();
      network.setOnline(value: false);
      final stopwatch = Stopwatch()..start();

      await club.commit(write);

      expect(stopwatch.elapsedMilliseconds, lessThan(30));
      expect(sends.pending, 1);
      server.release();
    });

    test(
      'behind a write that is still waiting it does not wait either',
      () async {
        server.hold();
        await club.commit(write);
        final stopwatch = Stopwatch()..start();

        await club.commit([
          const SetOp('clubs/c1/students/s2', {'n': 2}),
        ]);

        expect(stopwatch.elapsedMilliseconds, lessThan(30));
        expect(sends.pending, 2);
        server.release();
      },
    );

    test('a refusal that comes after the grace reaches the tracker, '
        'not the caller', () async {
      server.hold();
      await club.commit(write);

      server.reject(const StoreFailure(StoreFailureCode.permissionDenied));
      await pumpEventQueue();

      expect(sends.hasFailure, isTrue);
      expect(sends.lastFailure!.code, StoreFailureCode.permissionDenied);
    });

    test('a refusal that comes in time fails the caller', () async {
      server.failing = StoreFailureCode.permissionDenied;

      await expectLater(club.commit(write), throwsA(isA<StoreFailure>()));
      expect(sends.pending, 0);
    });

    test('when the write is refused, the fallback is sent instead and the '
        'refusal is not reported', () async {
      server.hold();
      var fallbackRuns = 0;
      await club.commit(
        write,
        ifRefused: () async {
          fallbackRuns++;
          await club.commit([
            const SetOp('clubs/c1/students/s1', {
              'recovered': true,
            }, merge: true),
          ]);
        },
      );

      server
        ..reject(const StoreFailure(StoreFailureCode.permissionDenied))
        ..release();
      await pumpEventQueue();

      expect(fallbackRuns, 1);
      expect(sends.hasFailure, isFalse);
      expect(server.read('clubs/c1/students/s1')!['recovered'], true);
    });

    test('the fallback is not tried for an unavailable server', () async {
      server.hold();
      var fallbackRuns = 0;
      await club.commit(write, ifRefused: () async => fallbackRuns++);

      server.reject(const StoreFailure(StoreFailureCode.unavailable));
      await pumpEventQueue();

      expect(fallbackRuns, 0);
      expect(sends.lastFailure!.code, StoreFailureCode.unavailable);
    });

    test('a fallback that fails is reported', () async {
      server.hold();
      await club.commit(
        write,
        ifRefused: () async =>
            throw const StoreFailure(StoreFailureCode.permissionDenied, 'bis'),
      );

      server.reject(const StoreFailure(StoreFailureCode.permissionDenied));
      await pumpEventQueue();

      expect(sends.lastFailure!.detail, 'bis');
    });

    test('mayAwaitServer says whether a transaction is worth trying', () async {
      expect(club.mayAwaitServer, isTrue);

      network.setOnline(value: false);
      expect(club.mayAwaitServer, isFalse);

      network.setOnline(value: true);
      server.hold();
      await club.commit(write);
      expect(club.mayAwaitServer, isFalse, reason: 'un envoi attend déjà');
      server.release();
    });

    test('a creation transaction that never answers is an unavailable '
        'server after the grace', () async {
      server.hold();

      await expectLater(
        club.createIfAbsent('clubs/c1/records/x', {'a': 1}),
        throwsA(
          isA<StoreFailure>().having(
            (f) => f.code,
            'code',
            StoreFailureCode.unavailable,
          ),
        ),
      );
    });

    test('without a tracker the write is awaited, as before', () async {
      final plain = ClubStore(server, world.scope);
      server.hold();
      var done = false;
      final pending = plain.commit(write).then((_) => done = true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(done, isFalse);

      server.release();
      await pending;
      expect(done, isTrue);
    });
  });
}

/// Un serveur dont les accusés se commandent : `hold` retient les lots (ils
/// sont appliqués au cache, pas acquittés), `release` les acquitte, `reject`
/// les refuse.
class _SlowStore extends InMemoryDocumentStore {
  Completer<void>? _gate;

  void hold() => _gate = Completer<void>();

  void release() {
    _gate?.complete();
    _gate = null;
  }

  void reject(StoreFailure failure) {
    _gate?.completeError(failure);
    _gate = null;
  }

  @override
  Future<void> commit(List<WriteOp> operations) async {
    final gate = _gate;
    if (gate != null) {
      // Appliqué localement tout de suite, acquitté plus tard (ou refusé).
      await super.commit(operations);
      await gate.future;
      return;
    }
    await super.commit(operations);
  }

  @override
  Future<bool> createIfAbsent(String path, Fields fields) async {
    final gate = _gate;
    if (gate != null) await gate.future;
    return await super.createIfAbsent(path, fields);
  }
}
