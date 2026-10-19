import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/stream_log.dart';

void main() {
  late InMemoryDocumentStore store;
  final now = DateTime(2026, 10, 12, 9, 30);

  setUp(() {
    store = InMemoryDocumentStore()..serverNow = () => now;
  });

  test('get returns a copy: changing it does not change the store', () async {
    store.seed('clubs/c1', {
      'name': 'A',
      'groupIds': ['g1'],
      'nested': {'k': 1},
    });

    final first = (await store.get('clubs/c1'))!;
    (first.fields['groupIds']! as List<Object?>).add('g2');
    (first.fields['nested']! as Map<String, Object?>)['k'] = 2;

    final second = (await store.get('clubs/c1'))!;
    expect(second.fields['groupIds'], ['g1']);
    expect(second.fields['nested'], {'k': 1});
    expect(second.id, 'c1');
    expect(second.segments, ['clubs', 'c1']);
  });

  test(
    'peek reads the content without reads, failures or get overrides',
    () async {
      store.seed('clubs/a', {'n': 1});
      final reads = store.reads;
      store.failing = StoreFailureCode.unavailable;

      final found = await store.peek('clubs/a');

      expect(found!.fields, {'n': 1});
      expect(await store.peek('clubs/absent'), isNull);
      expect(store.reads, reads);
    },
  );

  test(
    'createIfAbsent creates once and leaves an existing document alone',
    () async {
      expect(
        await store.createIfAbsent('clubs/a', {'n': 1, 't': serverTimestamp}),
        isTrue,
      );
      expect(await store.createIfAbsent('clubs/a', {'n': 2}), isFalse);

      expect(store.read('clubs/a'), {'n': 1, 't': now});
    },
  );

  test(
    'createIfAbsent fails like any operation when the store fails',
    () async {
      store.failing = StoreFailureCode.unavailable;

      await expectLater(
        store.createIfAbsent('clubs/a', {'n': 1}),
        throwsA(isA<StoreFailure>()),
      );
    },
  );

  test('a missing document is null', () async {
    expect(await store.get('clubs/none'), isNull);
  });

  test('list returns the direct children, sorted by id', () async {
    store
      ..seed('clubs/b', {'n': 2})
      ..seed('clubs/a', {'n': 1})
      ..seed('clubs/a/members/u1', {'n': 3})
      ..seed('other/x', {'n': 4});

    final docs = await store.list('clubs');

    expect([for (final d in docs) d.path], ['clubs/a', 'clubs/b']);
    expect([for (final d in await store.list('clubs/a/members')) d.id], ['u1']);
  });

  test('query filters one collection, direct children only, by id', () async {
    store
      ..seed('clubs/c1/memberships/b', {'groupId': 'g1'})
      ..seed('clubs/c1/memberships/a', {'groupId': 'g1'})
      ..seed('clubs/c1/memberships/c', {'groupId': 'g2'})
      ..seed('clubs/c2/memberships/d', {'groupId': 'g1'})
      ..seed('clubs/c1/memberships/a/deep/x', {'groupId': 'g1'});

    final docs = await store.query(
      'clubs/c1/memberships',
      const FieldEquals('groupId', 'g1'),
    );

    expect([for (final d in docs) d.id], ['a', 'b']);
  });

  test(
    'query with AllEqual keeps the documents that match every equality',
    () async {
      final store = InMemoryDocumentStore()
        ..seed('c/a', {'groupId': 'g1', 'sessionId': 'x1'})
        ..seed('c/b', {'groupId': 'g1', 'sessionId': 'x2'})
        ..seed('c/d', {'groupId': 'g2', 'sessionId': 'x1'});

      final docs = await store.query(
        'c',
        AllEqual(const [
          FieldEquals('groupId', 'g1'),
          FieldEquals('sessionId', 'x1'),
        ]),
      );

      expect([for (final d in docs) d.id], ['a']);
    },
  );

  test('query array-contains-any needs a list sharing one value', () async {
    store
      ..seed('clubs/c1/students/s1', {
        'groupIds': ['g1'],
      })
      ..seed('clubs/c1/students/s2', {
        'groupIds': ['g2', 'g3'],
      })
      ..seed('clubs/c1/students/s3', {'groupIds': <String>[]})
      ..seed('clubs/c1/students/s4', {'groupIds': 'g1'});

    final docs = await store.query(
      'clubs/c1/students',
      const FieldArrayContainsAny('groupIds', ['g1', 'g3']),
    );

    expect([for (final d in docs) d.id], ['s1', 's2']);
  });

  test('query counts as a read and obeys the simulated failure', () async {
    store.failing = StoreFailureCode.permissionDenied;

    await expectLater(
      store.query('a', const FieldEquals('x', 1)),
      throwsA(isA<StoreFailure>()),
    );
    expect(store.reads, 1);
  });

  test(
    'collectionGroup finds same-named collections anywhere, filtered',
    () async {
      store
        ..seed('clubs/c1/members/u1', {'uid': 'u1'})
        ..seed('clubs/c2/members/u1', {'uid': 'u1'})
        ..seed('clubs/c2/members/u2', {'uid': 'u2'})
        ..seed('clubs/c1/members/u1/members/deep', {'uid': 'u1'})
        ..seed('members/top', {'uid': 'u1'})
        ..seed('clubs/c1/groups/u1', {'uid': 'u1'});

      final docs = await store.collectionGroup(
        'members',
        field: 'uid',
        equalTo: 'u1',
      );

      expect(
        [for (final d in docs) d.path],
        [
          'clubs/c1/members/u1',
          'clubs/c1/members/u1/members/deep',
          'clubs/c2/members/u1',
          'members/top',
        ],
      );
    },
  );

  test('a batch applies set, update and delete together', () async {
    store
      ..seed('a/1', {'x': 1, 'y': 1})
      ..seed('a/2', {'x': 2});

    await store.commit([
      const SetOp('a/3', {'x': 3}),
      const UpdateOp('a/1', {'y': 9}),
      const DeleteOp('a/2'),
    ]);

    expect(store.read('a/1'), {'x': 1, 'y': 9});
    expect(store.read('a/2'), isNull);
    expect(store.read('a/3'), {'x': 3});
  });

  test('a failing update leaves the whole batch unapplied', () async {
    store.seed('a/1', {'x': 1});

    await expectLater(
      store.commit([
        const SetOp('a/new', {'x': 1}),
        const DeleteOp('a/1'),
        const UpdateOp('a/missing', {'x': 1}),
      ]),
      throwsA(
        isA<StoreFailure>().having(
          (e) => e.code,
          'code',
          StoreFailureCode.notFound,
        ),
      ),
    );

    expect(store.read('a/new'), isNull);
    expect(store.read('a/1'), {'x': 1});
  });

  test('the batch sees its own earlier writes', () async {
    await store.commit([
      const SetOp('a/1', {'x': 1}),
      const UpdateOp('a/1', {'y': 2}),
    ]);
    expect(store.read('a/1'), {'x': 1, 'y': 2});
  });

  test('set replaces the whole document', () async {
    store.seed('a/1', {'x': 1, 'y': 1});
    await store.commit([
      const SetOp('a/1', {'z': 3}),
    ]);
    expect(store.read('a/1'), {'z': 3});
  });

  test(
    'server timestamps become the server time, in sets and updates',
    () async {
      await store.commit([
        const SetOp('a/1', {'at': serverTimestamp, 'n': 1}),
      ]);
      expect(store.read('a/1'), {'at': now, 'n': 1});

      store.serverNow = () => now.add(const Duration(hours: 1));
      await store.commit([
        const UpdateOp('a/1', {'at': serverTimestamp}),
      ]);
      expect(store.read('a/1')!['at'], now.add(const Duration(hours: 1)));
    },
  );

  test('array union and removal edit the stored list atomically', () async {
    store.seed('a/1', {
      'ids': ['x', 'y'],
    });
    await store.commit([
      const UpdateOp('a/1', {
        'ids': ArrayUnion(['y', 'z']),
      }),
    ]);
    expect(store.read('a/1'), {
      'ids': ['x', 'y', 'z'],
    });

    await store.commit([
      const UpdateOp('a/1', {
        'ids': ArrayRemove(['x', 'absent']),
      }),
    ]);
    expect(store.read('a/1'), {
      'ids': ['y', 'z'],
    });
  });

  test('array union on a missing or absent field starts a list', () async {
    store.seed('a/1', {'n': 1});
    await store.commit([
      const UpdateOp('a/1', {
        'ids': ArrayUnion(['x']),
      }),
    ]);
    expect(store.read('a/1'), {
      'n': 1,
      'ids': ['x'],
    });
  });

  test('a merging set keeps the other fields, and creates if absent', () async {
    store.seed('a/1', {
      'keep': 1,
      'ids': ['x'],
    });
    await store.commit([
      const SetOp('a/1', {'n': 2, 'ids': ArrayUnion([])}, merge: true),
      const SetOp('a/2', {'n': 3}, merge: true),
    ]);

    expect(store.read('a/1'), {
      'keep': 1,
      'n': 2,
      'ids': ['x'],
    });
    expect(store.read('a/2'), {'n': 3});
  });

  test('failing makes every operation fail with that code', () async {
    store
      ..seed('a/1', {'x': 1})
      ..failing = StoreFailureCode.unavailable;

    for (final operation in <Future<Object?> Function()>[
      () => store.get('a/1'),
      () => store.list('a'),
      () => store.collectionGroup('a', field: 'x', equalTo: 1),
      () => store.commit([const DeleteOp('a/1')]),
    ]) {
      await expectLater(
        operation(),
        throwsA(
          isA<StoreFailure>().having(
            (e) => e.code,
            'code',
            StoreFailureCode.unavailable,
          ),
        ),
      );
    }
    expect(store.read('a/1'), {'x': 1}, reason: 'rien n’a été supprimé');
  });

  test('counts reads and commits, documents is a defensive copy', () async {
    await store.get('a/1');
    await store.list('a');
    await store.commit([
      const SetOp('a/1', {'x': 1}),
    ]);

    expect(store.reads, 2);
    expect(store.commits, 1);
    store.documents['a/1']!['x'] = 99;
    expect(store.read('a/1'), {'x': 1});
    store.remove('a/1');
    expect(store.read('a/1'), isNull);
  });

  test('StoreFailure prints its code and detail', () {
    expect(
      const StoreFailure(StoreFailureCode.other).toString(),
      'StoreFailure(other)',
    );
    expect(
      const StoreFailure(StoreFailureCode.permissionDenied, 'x').toString(),
      'StoreFailure(permissionDenied: x)',
    );
  });

  group('watches', () {
    test(
      'a batch reaches a watcher as ONE state, never half applied',
      () async {
        final log = StreamLog(store.watchCollection('clubs/c1/students'));
        await log.settle();

        await store.commit([
          const SetOp('clubs/c1/students/s1', {'n': 1}),
          const SetOp('clubs/c1/students/s2', {'n': 2}),
        ]);
        await log.settle();

        expect(
          [
            for (final u in log.values) [for (final d in u.documents) d.id],
          ],
          [
            <String>[],
            ['s1', 's2'],
          ],
        );
        await log.cancel();
      },
    );

    test(
      'a write that changes nothing the watcher sees emits nothing',
      () async {
        store.seed('clubs/c1/students/s1', {'n': 1});
        final log = StreamLog(store.watchDocument('clubs/c1/students/s1'));
        await log.settle();

        await store.commit([
          const SetOp('clubs/c1/students/s1', {'n': 1}),
        ]);
        await log.settle();

        expect(log.values, hasLength(1));
        await log.cancel();
      },
    );

    test('seed and remove reach the watchers too', () async {
      final log = StreamLog(store.watchDocument('clubs/c1/students/s1'));
      await log.settle();

      store.seed('clubs/c1/students/s1', {'n': 1});
      await log.settle();
      store.remove('clubs/c1/students/s1');
      await log.settle();

      expect(
        [for (final u in log.values) u.document?.fields['n']],
        [null, 1, null],
      );
      await log.cancel();
    });

    test('cancelling leaves no watcher behind', () async {
      final a = StreamLog(store.watchDocument('clubs/c1/students/s1'));
      final b = StreamLog(store.watchCollection('clubs/c1/students'));
      final c = StreamLog(
        store.watchQuery('clubs/c1/students', const FieldEquals('n', 1)),
      );
      await a.settle();
      expect(store.activeWatchers, 3);

      await a.cancel();
      await b.cancel();
      await c.cancel();

      expect(store.activeWatchers, 0);
    });

    test('a failing store refuses the watch and closes it', () async {
      store.failing = StoreFailureCode.unavailable;

      final log = StreamLog(store.watchDocument('clubs/c1/students/s1'));
      await log.settle();

      expect(log.values, isEmpty);
      expect(log.errors.single, isA<StoreFailure>());
      expect(log.done, isTrue);
      expect(store.activeWatchers, 0);
    });

    test(
      'revoking access fails and closes the watchers under the path',
      () async {
        final under = StreamLog(store.watchCollection('clubs/c1/students'));
        final other = StreamLog(store.watchCollection('clubs/c2/students'));
        await under.settle();

        store.revoke('clubs/c1/');
        await under.settle();

        expect(
          under.errors.single,
          isA<StoreFailure>().having(
            (e) => e.code,
            'code',
            StoreFailureCode.permissionDenied,
          ),
        );
        expect(under.done, isTrue);
        expect(other.done, isFalse);
        expect(store.activeWatchers, 1);
        await other.cancel();
      },
    );

    test(
      'a revoked path stays refused for reads and new watches until restored',
      () async {
        store.revoke('clubs/c1/');

        await expectLater(
          store.get('clubs/c1/students/s1'),
          throwsA(isA<StoreFailure>()),
        );
        await expectLater(
          store.list('clubs/c1/students'),
          throwsA(isA<StoreFailure>()),
        );
        final refused = StreamLog(store.watchCollection('clubs/c1/students'));
        await refused.settle();
        expect(refused.errors, hasLength(1));

        store.restore('clubs/c1/');
        expect(await store.list('clubs/c1/students'), isEmpty);
        final back = StreamLog(store.watchCollection('clubs/c1/students'));
        await back.settle();
        expect(back.values, hasLength(1));
        await back.cancel();
      },
    );
  });
}
