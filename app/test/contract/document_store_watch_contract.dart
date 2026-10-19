import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stream_log.dart';

/// Un stock de documents neuf, vu par un seul client.
typedef WatchHarness = ({DocumentStore store, Future<void> Function() close});

/// Le contrat des **flux** du `DocumentStore` (FB5b, ADR 0024 décision 28) :
/// l'état courant d'abord, puis un état à chaque changement, pour un document,
/// une collection ou une requête ; indépendance des flux ; annulation. Joué
/// sur le double en mémoire et sur le vrai `FirestoreDocumentStore` (faux
/// Firestore) ; le flux réel (deux clients, règles) l'est contre l'émulateur
/// (`scripts/rules_test/watch.test.mjs`).
///
/// Ce que le contrat ne dit pas : les métadonnées `fromCache` et
/// `hasPendingWrites` n'y sont lues que par leur type, parce que le faux
/// Firestore n'a pas de cache serveur (voir `testing.md`).
void documentStoreWatchContract(
  String name,
  Future<WatchHarness> Function() open,
) {
  group('$name : flux du stock de documents', () {
    late WatchHarness harness;
    late DocumentStore store;
    final logs = <StreamLog<Object?>>[];

    setUp(() async {
      harness = await open();
      store = harness.store;
    });

    tearDown(() async {
      for (final log in logs) {
        await log.cancel();
      }
      logs.clear();
      await harness.close();
    });

    StreamLog<T> listen<T>(Stream<T> stream) {
      final log = StreamLog<T>(stream);
      logs.add(log as StreamLog<Object?>);
      return log;
    }

    Future<void> write(List<WriteOp> operations) => store.commit(operations);

    test('a document watch starts with the current state', () async {
      await write([
        const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
      ]);

      final log = listen(store.watchDocument('clubs/c1/students/s1'));
      await log.settle();

      expect(log.values, hasLength(1));
      expect(log.last.document!.fields['firstName'], 'Léa');
      expect(log.last.document!.path, 'clubs/c1/students/s1');
    });

    test('a document watch on an absent document starts empty', () async {
      final log = listen(store.watchDocument('clubs/c1/students/s1'));
      await log.settle();

      expect(log.values, hasLength(1));
      expect(log.last.document, isNull);
    });

    test('a document watch follows create, update and delete', () async {
      final log = listen(store.watchDocument('clubs/c1/students/s1'));
      await log.settle();

      await write([
        const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
      ]);
      await log.settle();
      await write([
        const UpdateOp('clubs/c1/students/s1', {'firstName': 'Léa B.'}),
      ]);
      await log.settle();
      await write([const DeleteOp('clubs/c1/students/s1')]);
      await log.settle();

      expect(
        [for (final update in log.values) update.document?.fields['firstName']],
        [null, 'Léa', 'Léa B.', null],
      );
    });

    test('a document watch ignores the other documents', () async {
      final log = listen(store.watchDocument('clubs/c1/students/s1'));
      await log.settle();

      await write([
        const SetOp('clubs/c1/students/s2', {'firstName': 'Tom'}),
      ]);
      await log.settle();

      expect(log.values, hasLength(1));
    });

    test('a collection watch lists the documents sorted by id', () async {
      await write([
        const SetOp('clubs/c1/students/s2', {'firstName': 'Tom'}),
        const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
        const SetOp('clubs/c1/groups/g1', {'name': 'Mardi'}),
      ]);

      final log = listen(store.watchCollection('clubs/c1/students'));
      await log.settle();

      expect(log.values, hasLength(1));
      expect([for (final d in log.last.documents) d.id], ['s1', 's2']);
    });

    test('a collection watch follows additions and removals', () async {
      final log = listen(store.watchCollection('clubs/c1/students'));
      await log.settle();
      expect(log.last.documents, isEmpty);

      await write([
        const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
      ]);
      await log.settle();
      await write([
        const SetOp('clubs/c1/students/s2', {'firstName': 'Tom'}),
      ]);
      await log.settle();
      await write([const DeleteOp('clubs/c1/students/s1')]);
      await log.settle();

      expect(
        [
          for (final update in log.values)
            [for (final d in update.documents) d.id],
        ],
        [
          <String>[],
          ['s1'],
          ['s1', 's2'],
          ['s2'],
        ],
      );
    });

    test(
      'a collection watch ignores a sub-collection and its siblings',
      () async {
        final log = listen(store.watchCollection('clubs/c1/students'));
        await log.settle();

        await write([
          const SetOp('clubs/c1/students/s1/notes/n1', {'text': 'x'}),
          const SetOp('clubs/c1/groups/g1', {'name': 'Mardi'}),
        ]);
        await log.settle();

        expect(log.values.last.documents, isEmpty);
      },
    );

    test('a query watch follows documents entering and leaving it', () async {
      final log = listen(
        store.watchQuery(
          'clubs/c1/records',
          const FieldEquals('groupId', 'g1'),
        ),
      );
      await log.settle();

      await write([
        const SetOp('clubs/c1/records/r1', {'groupId': 'g1'}),
        const SetOp('clubs/c1/records/r2', {'groupId': 'g2'}),
      ]);
      await log.settle();
      await write([
        const UpdateOp('clubs/c1/records/r1', {'groupId': 'g2'}),
      ]);
      await log.settle();

      expect(
        [
          for (final update in log.values)
            [for (final d in update.documents) d.id],
        ],
        [
          <String>[],
          ['r1'],
          <String>[],
        ],
      );
    });

    test('a query watch supports array-contains-any', () async {
      await write([
        const SetOp('clubs/c1/students/s1', {
          'groupIds': ['g1'],
        }),
        const SetOp('clubs/c1/students/s2', {
          'groupIds': ['g2'],
        }),
      ]);
      final log = listen(
        store.watchQuery(
          'clubs/c1/students',
          const FieldArrayContainsAny('groupIds', ['g1', 'g3']),
        ),
      );
      await log.settle();

      expect([for (final d in log.last.documents) d.id], ['s1']);

      await write([
        const SetOp('clubs/c1/students/s3', {
          'groupIds': ['g3'],
        }),
      ]);
      await log.settle();

      expect([for (final d in log.last.documents) d.id], ['s1', 's3']);
    });

    test('a query watch supports several equalities', () async {
      final log = listen(
        store.watchQuery(
          'clubs/c1/attempts',
          AllEqual(const [
            FieldEquals('groupId', 'g1'),
            FieldEquals('studentId', 's1'),
          ]),
        ),
      );
      await log.settle();

      await write([
        const SetOp('clubs/c1/attempts/a1', {
          'groupId': 'g1',
          'studentId': 's1',
        }),
        const SetOp('clubs/c1/attempts/a2', {
          'groupId': 'g1',
          'studentId': 's2',
        }),
      ]);
      await log.settle();

      expect([for (final d in log.last.documents) d.id], ['a1']);
    });

    test('a batch ends in the state with all its writes', () async {
      final log = listen(store.watchCollection('clubs/c1/students'));
      await log.settle();

      // Le faux Firestore livre un lot document par document ; le SDK réel
      // l'applique d'un bloc (prouvé contre l'émulateur, `watch.test.mjs`).
      await write([
        const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
        const SetOp('clubs/c1/students/s2', {'firstName': 'Tom'}),
      ]);
      await log.settle();

      expect([for (final d in log.last.documents) d.id], ['s1', 's2']);
    });

    test('watchers are independent of each other', () async {
      final first = listen(store.watchDocument('clubs/c1/students/s1'));
      final second = listen(store.watchDocument('clubs/c1/students/s1'));
      await first.settle();

      await first.cancel();
      await write([
        const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
      ]);
      await second.settle();

      expect(first.values, hasLength(1));
      expect(second.last.document!.fields['firstName'], 'Léa');
    });

    test('a cancelled watch receives nothing more', () async {
      final log = listen(store.watchCollection('clubs/c1/students'));
      await log.settle();
      await log.cancel();

      await write([
        const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
      ]);
      await log.settle();

      expect(log.values, hasLength(1));
    });

    test('snapshots carry their metadata', () async {
      final document = listen(store.watchDocument('clubs/c1/students/s1'));
      final collection = listen(store.watchCollection('clubs/c1/students'));
      await document.settle();

      expect(document.last.metadata, isA<UpdateMetadata>());
      expect(collection.last.metadata, isA<UpdateMetadata>());
    });
  });
}
