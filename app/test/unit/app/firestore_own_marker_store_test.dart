import 'dart:async';

import 'package:billard_cfa/app/firestore_own_marker_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un stock qui note les requêtes au serveur et peut ne jamais répondre à un
/// lot. **Hors ligne** ([offline]), il joue le cache du SDK : une requête
/// ordinaire rend ce que le cache connaît (ici : rien), une requête au
/// serveur échoue en `unavailable`.
class _Recording extends InMemoryDocumentStore {
  final List<(String, QueryFilter)> queries = [];
  final List<List<WriteOp>> lots = [];
  bool silent = false;
  bool offline = false;

  @override
  Future<List<StoredDocument>> query(String collection, QueryFilter filter) =>
      offline ? Future.value(const []) : super.query(collection, filter);

  @override
  Future<List<StoredDocument>> queryFromServer(
    String collection,
    QueryFilter filter,
  ) {
    queries.add((collection, filter));
    if (offline) {
      throw const StoreFailure(StoreFailureCode.unavailable, 'hors ligne');
    }
    return super.queryFromServer(collection, filter);
  }

  @override
  Future<void> commit(List<WriteOp> operations) {
    lots.add(operations);
    if (silent) return Completer<void>().future;
    return super.commit(operations);
  }
}

void main() {
  const club = ClubId('c1');
  final key = 'ab' * 32;
  late _Recording documents;
  late FirestoreOwnMarkerStore store;

  setUp(() {
    documents = _Recording();
    store = FirestoreOwnMarkerStore(
      documents,
      SessionScope()..signIn(const UserId('u-me')),
      ackTimeout: const Duration(milliseconds: 20),
    );
  });

  test('the listing is filtered on the author, as the rules demand', () async {
    await store.list(club, MarkerKind.import);
    await store.list(club, MarkerKind.operation);

    expect(documents.queries.map((q) => q.$1), [
      'clubs/c1/imports',
      'clubs/c1/operations',
    ]);
    for (final (_, filter) in documents.queries) {
      expect(filter, isA<FieldEquals>());
      filter as FieldEquals;
      expect((filter.field, filter.value), ('createdBy', 'u-me'));
    }
  });

  test('offline, the listing is unavailable, never an empty list from the '
      'cache (the member must not go before the markers)', () async {
    documents
      ..seed('clubs/c1/imports/${key}_u-me', {'createdBy': 'u-me'})
      ..offline = true;

    await expectLater(
      store.list(club, MarkerKind.import),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.unavailable,
        ),
      ),
    );
  });

  test('a document whose id does not end with my uid is ignored', () async {
    documents
      ..seed('clubs/c1/imports/${key}_u-other', {'createdBy': 'u-me'})
      ..seed('clubs/c1/imports/${key}_u-me', {'createdBy': 'u-me'});

    expect(await store.list(club, MarkerKind.import), [
      OwnMarker(MarkerKind.import, key),
    ]);
  });

  test('each path is rebuilt with my uid, in one lot', () async {
    await store.delete(club, [
      OwnMarker(MarkerKind.import, key),
      OwnMarker(MarkerKind.operation, key),
    ]);

    expect(documents.lots.single.map((op) => (op is DeleteOp, op.path)), [
      (true, 'clubs/c1/imports/${key}_u-me'),
      (true, 'clubs/c1/operations/${key}_u-me'),
    ]);
  });

  test('listing then deleting my markers never removes the marker another '
      'author left, even under the same key or claiming my uid', () async {
    documents
      ..seed('clubs/c1/imports/${key}_u-me', {'createdBy': 'u-me'})
      ..seed('clubs/c1/imports/${key}_u-other', {'createdBy': 'u-other'})
      ..seed('clubs/c1/operations/${key}_u-other', {'createdBy': 'u-me'});

    for (final kind in MarkerKind.values) {
      await store.delete(club, await store.list(club, kind));
    }

    expect(documents.read('clubs/c1/imports/${key}_u-me'), isNull);
    expect(documents.read('clubs/c1/imports/${key}_u-other'), isNotNull);
    expect(documents.read('clubs/c1/operations/${key}_u-other'), isNotNull);
  });

  test('the server ack is awaited 30 seconds by default', () {
    expect(
      FirestoreOwnMarkerStore(documents, SessionScope()).ackTimeout,
      const Duration(seconds: 30),
    );
  });

  test('an empty deletion sends nothing', () async {
    await store.delete(club, const []);

    expect(documents.lots, isEmpty);
  });

  test('a lot without an answer from the server is unavailable', () async {
    documents.silent = true;

    await expectLater(
      store.delete(club, [OwnMarker(MarkerKind.import, key)]),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.unavailable,
        ),
      ),
    );
  });

  test('a refused lot is reported as denied', () async {
    documents.failing = StoreFailureCode.permissionDenied;

    await expectLater(
      store.delete(club, [OwnMarker(MarkerKind.import, key)]),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.denied,
        ),
      ),
    );
  });
}
