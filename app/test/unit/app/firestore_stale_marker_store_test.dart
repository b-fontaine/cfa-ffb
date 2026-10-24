import 'dart:async';

import 'package:billard_cfa/app/firestore_stale_marker_store.dart';
import 'package:billard_cfa/app/platform/firestore_document_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/domain/stale_markers.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/own_marker_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixed_clock.dart';
import '../../support/in_memory_write_ledger.dart';

/// Un stock qui note les requêtes et peut ne jamais répondre à un lot.
class _Recording extends InMemoryDocumentStore {
  final List<(String, QueryFilter)> queries = [];
  final List<List<WriteOp>> lots = [];
  bool silent = false;

  @override
  Future<List<StoredDocument>> query(String collection, QueryFilter filter) {
    queries.add((collection, filter));
    return super.query(collection, filter);
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
  final bound = DateTime.utc(2026, 7, 25);
  late _Recording documents;
  late FirestoreStaleMarkerStore store;

  setUp(() {
    documents = _Recording();
    store = FirestoreStaleMarkerStore(
      documents,
      ackTimeout: const Duration(milliseconds: 20),
    );
  });

  test('the listing is a range query on updatedAt in the club', () async {
    await store.list(club, MarkerKind.import, bound);
    await store.list(club, MarkerKind.operation, bound);

    expect(documents.queries.map((q) => q.$1), [
      'clubs/c1/imports',
      'clubs/c1/operations',
    ]);
    for (final (_, filter) in documents.queries) {
      expect(filter, isA<FieldBefore>());
      filter as FieldBefore;
      expect((filter.field, filter.value), ('updatedAt', bound));
    }
  });

  test('every author is listed; an id of another shape is ignored', () async {
    final old = DateTime.utc(2026, 6);
    documents
      ..seed('clubs/c1/imports/${key}_u-gone', {'updatedAt': old})
      ..seed('clubs/c1/imports/${key}_u-dir', {'updatedAt': old})
      ..seed('clubs/c1/imports/plain', {'updatedAt': old})
      ..seed('clubs/c1/imports/${'g' * 64}_u-x', {'updatedAt': old})
      ..seed('clubs/c1/imports/${key}_', {'updatedAt': old})
      ..seed('clubs/c1/imports/${'cd' * 32}_u-new', {
        'updatedAt': DateTime.utc(2026, 10),
      });

    expect(await store.list(club, MarkerKind.import, bound), [
      StaleMarker(MarkerKind.import, '${key}_u-dir'),
      StaleMarker(MarkerKind.import, '${key}_u-gone'),
    ]);
  });

  test(
    'each path is composed in the club and its collection, one lot',
    () async {
      await store.delete(club, [
        StaleMarker(MarkerKind.import, '${key}_u-gone'),
        StaleMarker(MarkerKind.operation, '${key}_u-gone'),
      ]);

      expect(documents.lots.single.map((op) => (op is DeleteOp, op.path)), [
        (true, 'clubs/c1/imports/${key}_u-gone'),
        (true, 'clubs/c1/operations/${key}_u-gone'),
      ]);
    },
  );

  test('an empty lot is not sent', () async {
    await store.delete(club, const []);

    expect(documents.lots, isEmpty);
  });

  test('more than 400 deletions are refused before any write', () async {
    await expectLater(
      store.delete(club, [
        for (var i = 0; i < 401; i++)
          StaleMarker(
            MarkerKind.import,
            '${i.toRadixString(16).padLeft(64, '0')}_u-gone',
          ),
      ]),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.other,
        ),
      ),
    );
    expect(documents.lots, isEmpty);
  });

  test('an id that is not a marker id is refused before any write', () async {
    for (final id in ['../members/u-dir', '${key}_a/b', 'plain', '${key}_']) {
      await expectLater(
        store.delete(club, [StaleMarker(MarkerKind.import, id)]),
        throwsA(isA<ServiceFailure>()),
        reason: id,
      );
    }
    expect(documents.lots, isEmpty);
  });

  test('a lot without an answer from the server is unavailable', () async {
    documents.silent = true;

    await expectLater(
      store.delete(club, [StaleMarker(MarkerKind.import, '${key}_u-gone')]),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.unavailable,
        ),
      ),
    );
  });

  test('a refusal of the rules is denied', () async {
    documents.failing = StoreFailureCode.permissionDenied;

    await expectLater(
      store.list(club, MarkerKind.operation, bound),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.denied,
        ),
      ),
    );
  });

  test('the server ack is awaited 30 seconds by default', () {
    expect(
      FirestoreStaleMarkerStore(documents).ackTimeout,
      const Duration(seconds: 30),
    );
  });

  test(
    'at the exact bounds: a marker is never aimed at before 91 days '
    '(90 days and one day of clock margin), and is one second later',
    () async {
      final now = DateTime.utc(2026, 10, 24, 10);
      String id(String hex) => '${hex * 32}_u-gone';
      documents
        ..seed('clubs/c1/operations/${id('a1')}', {
          'updatedAt': now.subtract(const Duration(days: 90)),
        })
        ..seed('clubs/c1/operations/${id('b2')}', {
          'updatedAt': now.subtract(const Duration(days: 91)),
        })
        ..seed('clubs/c1/operations/${id('c3')}', {
          'updatedAt': now.subtract(const Duration(days: 91, seconds: 1)),
        });
      final clock = FixedClock(now);
      final scope = SessionScope()
        ..signIn(const UserId('u-dir'))
        ..activate(club, Role.director);

      final result = await PurgeStaleMarkers(
        store,
        InMemoryWriteLedger(clock),
        clock,
        scope,
      )();

      expect(result.removed, 1);
      expect(documents.read('clubs/c1/operations/${id('a1')}'), isNotNull);
      expect(documents.read('clubs/c1/operations/${id('b2')}'), isNotNull);
      expect(documents.read('clubs/c1/operations/${id('c3')}'), isNull);
    },
  );

  test('through the SDK (fake_cloud_firestore), only the old ones', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('clubs/c1/operations/${key}_u-gone').set({
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 5)),
    });
    await firestore.doc('clubs/c1/operations/${'cd' * 32}_u-gone').set({
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 9)),
    });
    await firestore.doc('clubs/c2/operations/${key}_u-gone').set({
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 5)),
    });
    final sdk = FirestoreStaleMarkerStore(
      FirestoreDocumentStore(
        access: FirestoreSdkAccess(firestore: () => firestore),
      ),
    );

    final found = await sdk.list(club, MarkerKind.operation, bound);
    await sdk.delete(club, found);

    expect(found, [StaleMarker(MarkerKind.operation, '${key}_u-gone')]);
    expect(
      (await firestore.doc('clubs/c1/operations/${key}_u-gone').get()).exists,
      isFalse,
    );
    expect(
      (await firestore.doc('clubs/c2/operations/${key}_u-gone').get()).exists,
      isTrue,
    );
  });
}
