import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les appels du SDK, scriptés : ce que le magasin leur demande est enregistré.
class _FakeAccess implements FirestoreAccess {
  Map<String, dynamic>? document;
  List<RawDocument> collection = const [];
  Exception? error;
  final List<String> calls = [];
  List<RawWrite>? written;

  void _maybeFail() {
    if (error != null) throw error!;
  }

  @override
  Future<Map<String, dynamic>?> readDocument(String path) async {
    calls.add('doc $path');
    _maybeFail();
    return document;
  }

  @override
  Future<List<RawDocument>> readCollection(String path) async {
    calls.add('collection $path');
    _maybeFail();
    return collection;
  }

  @override
  Future<List<RawDocument>> readQuery(
    String path,
    String field, {
    required bool contains,
    required Object? value,
  }) async {
    calls.add('query $path $field ${contains ? 'any' : '='} $value');
    _maybeFail();
    return collection;
  }

  @override
  Future<List<RawDocument>> readQueryAll(
    String path,
    Map<String, Object?> equalities,
  ) async {
    final clauses = [for (final e in equalities.entries) '${e.key}=${e.value}'];
    calls.add('queryAll $path ${clauses.join(',')}');
    _maybeFail();
    return collection;
  }

  @override
  Future<List<RawDocument>> readGroup(
    String collectionId,
    String field,
    Object? equalTo,
  ) async {
    calls.add('group $collectionId $field=$equalTo');
    _maybeFail();
    return collection;
  }

  @override
  Future<void> writeBatch(List<RawWrite> writes) async {
    calls.add('batch');
    _maybeFail();
    written = writes;
  }

  bool created = true;
  Map<String, Object?>? createdData;

  @override
  Future<bool> createDocument(String path, Map<String, Object?> data) async {
    calls.add('create $path');
    _maybeFail();
    createdData = data;
    return created;
  }
}

FirebaseException _failure(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code, message: 'm');

void main() {
  late _FakeAccess access;
  late FirestoreDocumentStore store;

  setUp(() {
    access = _FakeAccess();
    store = FirestoreDocumentStore(access: access);
  });

  group('createIfAbsent', () {
    test('translates the values and reports a creation', () async {
      final created = await store.createIfAbsent('clubs/c1/records/x1', {
        'date': DateTime.utc(2026, 10, 3),
        'createdAt': serverTimestamp,
      });

      expect(created, isTrue);
      expect(access.calls, ['create clubs/c1/records/x1']);
      expect(access.createdData!['date'], isA<Timestamp>());
      expect(access.createdData!['createdAt'], isA<FieldValue>());
    });

    test('reports an existing document without failing', () async {
      access.created = false;

      expect(
        await store.createIfAbsent('clubs/c1/records/x1', {'a': 1}),
        isFalse,
      );
    });

    test('translates a refusal of the rules', () async {
      access.error = _failure('permission-denied');

      await expectLater(
        store.createIfAbsent('clubs/c1/records/x1', {'a': 1}),
        throwsA(
          isA<StoreFailure>().having(
            (e) => e.code,
            'code',
            StoreFailureCode.permissionDenied,
          ),
        ),
      );
    });
  });

  group('reads', () {
    test('a document: timestamps and nesting become plain values', () async {
      access.document = {
        'name': 'Club',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 12, 9, 30)),
        'groupIds': ['g1'],
        'nested': {'at': Timestamp.fromDate(DateTime.utc(2026))},
      };

      final found = (await store.get('clubs/c1'))!;

      expect(found.path, 'clubs/c1');
      expect(found.fields['name'], 'Club');
      expect(
        (found.fields['createdAt']! as DateTime).toUtc(),
        DateTime.utc(2026, 10, 12, 9, 30),
      );
      expect(found.fields['groupIds'], ['g1']);
      expect(
        ((found.fields['nested']! as Map<String, Object?>)['at']! as DateTime)
            .toUtc(),
        DateTime.utc(2026),
      );
      expect(access.calls, ['doc clubs/c1']);
    });

    test('a query goes to the SDK with its encoded filter', () async {
      access.collection = [
        (path: 'a/1', data: {'x': 1}),
      ];

      final byValue = await store.query(
        'clubs/c1/memberships',
        FieldEquals('groupId', DateTime.utc(2026)),
      );
      final byList = await store.query(
        'clubs/c1/students',
        const FieldArrayContainsAny('groupIds', ['g1', 'g2']),
      );

      expect([for (final d in byValue) d.path], ['a/1']);
      expect(byList, hasLength(1));
      expect(access.calls, [
        'query clubs/c1/memberships groupId = ${Timestamp.fromDate(DateTime.utc(2026))}',
        'query clubs/c1/students groupIds any [g1, g2]',
      ]);
    });

    test(
      'a conjunction of equalities is one query with encoded values',
      () async {
        access.collection = [
          (path: 'a/1', data: {'x': 1}),
        ];

        final found = await store.query(
          'clubs/c1/attempts',
          AllEqual(const [
            FieldEquals('groupId', 'g1'),
            FieldEquals('sessionId', 'x1'),
          ]),
        );

        expect([for (final d in found) d.path], ['a/1']);
        expect(access.calls, [
          'queryAll clubs/c1/attempts groupId=g1,sessionId=x1',
        ]);
      },
    );

    test('a missing document is null', () async {
      expect(await store.get('clubs/none'), isNull);
    });

    test('a collection keeps the path of each document', () async {
      access.collection = [
        (path: 'clubs/c1/members/u1', data: {'uid': 'u1'}),
        (path: 'clubs/c1/members/u2', data: {'uid': 'u2'}),
      ];

      final docs = await store.list('clubs/c1/members');

      expect(
        [for (final d in docs) d.path],
        ['clubs/c1/members/u1', 'clubs/c1/members/u2'],
      );
      expect(docs.first.fields, {'uid': 'u1'});
      expect(access.calls, ['collection clubs/c1/members']);
    });

    test('a collection group is filtered on one field with equality', () async {
      access.collection = [
        (path: 'clubs/c1/members/u1', data: {'uid': 'u1'}),
      ];

      final docs = await store.collectionGroup(
        'members',
        field: 'uid',
        equalTo: 'u1',
      );

      expect([for (final d in docs) d.path], ['clubs/c1/members/u1']);
      expect(access.calls, ['group members uid=u1']);
    });
  });

  group('commit', () {
    test(
      'sends every write in ONE call, encoding dates and server time',
      () async {
        await store.commit([
          SetOp('a/1', {
            'at': serverTimestamp,
            'expires': DateTime.utc(2026, 10, 14),
            'list': [DateTime.utc(2026), 'x'],
            'map': {'k': serverTimestamp},
          }),
          const UpdateOp('a/2', {'used': true}),
          const DeleteOp('a/3'),
        ]);

        expect(access.calls, ['batch']);
        final writes = access.written!;
        expect(
          [for (final w in writes) (w.path, w.kind)],
          [
            ('a/1', RawWriteKind.set),
            ('a/2', RawWriteKind.update),
            ('a/3', RawWriteKind.delete),
          ],
        );
        final set = writes[0].data!;
        expect(set['at'], isA<FieldValue>());
        expect(set['expires'], Timestamp.fromDate(DateTime.utc(2026, 10, 14)));
        expect(set['list'], [Timestamp.fromDate(DateTime.utc(2026)), 'x']);
        expect((set['map']! as Map<String, Object?>)['k'], isA<FieldValue>());
        expect(writes[1].data, {'used': true});
        expect(writes[2].data, isNull);
      },
    );

    test('a merging set is sent as a merging set', () async {
      await store.commit([
        const SetOp('a/1', {'n': 1}, merge: true),
        const SetOp('a/2', {'n': 1}),
      ]);

      expect(access.written!.map((w) => w.kind), [
        RawWriteKind.setMerge,
        RawWriteKind.set,
      ]);
    });

    test('array union and removal become the SDK sentinels', () async {
      await store.commit([
        const UpdateOp('a/1', {
          'ids': ArrayUnion(['x']),
          'old': ArrayRemove(['y']),
        }),
      ]);
      final data = access.written!.single.data!;
      expect(data['ids'], isA<FieldValue>());
      expect(data['old'], isA<FieldValue>());
      expect(data['ids'], isNot(equals(data['old'])));
    });

    test('encoding then decoding returns the same plain values', () {
      final fields = {
        'at': DateTime.utc(2026, 10, 12),
        'ids': ['a', 'b'],
        'nested': {'n': 1, 'd': DateTime.utc(2026)},
        'flag': true,
        'none': null,
      };

      final decoded = FirestoreDocumentStore.decodeFields(
        FirestoreDocumentStore.encodeFields(fields),
      );

      expect((decoded['at']! as DateTime).toUtc(), fields['at']);
      expect(decoded['ids'], ['a', 'b']);
      expect(
        ((decoded['nested']! as Map<String, Object?>)['d']! as DateTime)
            .toUtc(),
        DateTime.utc(2026),
      );
      expect(decoded['flag'], true);
      expect(decoded['none'], isNull);
    });
  });

  group('failures', () {
    test('translates the codes of the SDK, whatever the operation', () async {
      for (final (sdk, expected) in [
        ('permission-denied', StoreFailureCode.permissionDenied),
        ('failed-precondition', StoreFailureCode.failedPrecondition),
        ('not-found', StoreFailureCode.notFound),
        ('unavailable', StoreFailureCode.unavailable),
        ('deadline-exceeded', StoreFailureCode.unavailable),
        ('aborted', StoreFailureCode.other),
      ]) {
        access.error = _failure(sdk);
        for (final operation in <Future<Object?> Function()>[
          () => store.get('a/1'),
          () => store.list('a'),
          () => store.collectionGroup('a', field: 'x', equalTo: 1),
          () => store.commit([const DeleteOp('a/1')]),
        ]) {
          await expectLater(
            operation(),
            throwsA(
              isA<StoreFailure>()
                  .having((e) => e.code, 'code', expected)
                  .having((e) => e.detail, 'detail', '$sdk: m'),
            ),
            reason: sdk,
          );
        }
      }
    });

    test('an exception that is not the SDK’s is not swallowed', () async {
      access.error = const FormatException('autre chose');
      await expectLater(store.get('a/1'), throwsFormatException);
    });
  });
}
