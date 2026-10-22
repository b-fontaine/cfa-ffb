import 'dart:async';

import 'package:billard_cfa/app/firestore_operation_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/operations_world.dart';

/// Un stock qui ne répond jamais à un lot (hors ligne : l'accusé ne vient pas).
class _Silent extends OperationsRulesStore {
  _Silent(super.inner);

  @override
  Future<void> commit(List<WriteOp> operations) => Completer<void>().future;
}

void main() {
  const key =
      'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';
  late InMemoryDocumentStore server;
  late OperationsRulesStore rules;
  late SessionScope scope;
  late FirestoreOperationStore store;

  OperationMarker marker({int done = 1, int stage = 0}) => OperationMarker(
    key: key,
    kind: OperationKind.erasure,
    done: done,
    stage: stage,
    role: Role.director,
  );

  OperationLotCommit commit({
    required OperationMarker after,
    bool creates = false,
    bool finishes = false,
    OperationLot? lot,
  }) => OperationLotCommit(
    lot: lot ?? OperationLot.empty,
    marker: after,
    createsMarker: creates,
    finishes: finishes,
  );

  setUp(() {
    server = InMemoryDocumentStore();
    rules = OperationsRulesStore(server)..authUid = 'u-dir';
    scope = SessionScope()
      ..signIn(const UserId('u-dir'))
      ..activate(const ClubId('c1'), Role.director);
    store = FirestoreOperationStore(ClubStore(rules, scope), scope);
  });

  String path() => 'clubs/c1/operations/${key}_u-dir';

  test('the marker of an unknown operation is absent', () async {
    expect(await store.readMarker(key), isNull);
  });

  test('the first lot creates the marker, the last one deletes it', () async {
    await store.commit(commit(after: marker(), creates: true));
    expect(server.read(path())!['done'], 1);
    expect((await store.readMarker(key))!.done, 1);

    await store.commit(commit(after: marker(done: 2, stage: 1)));
    expect(server.read(path())!['done'], 2);
    expect(server.read(path())!['stage'], 1);

    await store.commit(
      commit(after: marker(done: 3, stage: 2), finishes: true),
    );
    expect(server.read(path()), isNull);
    expect(await store.readMarker(key), isNull);
  });

  test(
    'the writes of the lot and the marker leave in one atomic batch',
    () async {
      var applied = 0;
      final lot = OperationLot(
        writes: 1,
        apply: () async {
          applied++;
          await ClubStore(rules, scope).commit([
            const SetOp('clubs/c1/students/s1', {'firstName': 'Léa'}),
          ]);
        },
      );

      await store.commit(commit(after: marker(), creates: true, lot: lot));

      expect(applied, 1);
      expect(rules.appliedBatches, 1);
      expect(rules.log.single, ['clubs/c1/students/s1', path()]);
    },
  );

  test(
    'a lot that is refused writes none of its data and leaves the marker',
    () async {
      final lot = OperationLot(
        writes: 1,
        apply: () async => await ClubStore(rules, scope).commit([
          const SetOp('clubs/c1/attempts/a1', {'studentId': 'absent'}),
        ]),
      );

      await expectLater(
        store.commit(commit(after: marker(), creates: true, lot: lot)),
        throwsA(
          isA<ServiceFailure>().having(
            (f) => f.code,
            'code',
            ServiceFailureCode.denied,
          ),
        ),
      );

      expect(server.read('clubs/c1/attempts/a1'), isNull);
      expect(server.read(path()), isNull);
    },
  );

  test(
    'a single lot that creates and finishes writes no marker at all',
    () async {
      await store.commit(
        commit(after: marker(), creates: true, finishes: true),
      );

      expect(server.documents, isEmpty);
      expect(rules.appliedBatches, 0, reason: 'un lot vide ne part pas');
    },
  );

  test('a lot replayed after the marker moved is refused', () async {
    await store.commit(commit(after: marker(), creates: true));
    await store.commit(commit(after: marker(done: 2)));

    await expectLater(
      store.commit(commit(after: marker(done: 2))),
      throwsA(isA<ServiceFailure>()),
    );
  });

  test('without the server answering, the lot is said unavailable', () async {
    final silent = FirestoreOperationStore(
      ClubStore(_Silent(server), scope),
      scope,
      ackTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      silent.commit(commit(after: marker(), creates: true)),
      throwsA(
        isA<ServiceFailure>().having(
          (f) => f.code,
          'code',
          ServiceFailureCode.unavailable,
        ),
      ),
    );
  });

  test('a lot of more than 500 writes is refused before any write', () async {
    final lot = OperationLot(
      writes: 501,
      apply: () async => await ClubStore(rules, scope).commit([
        for (var i = 0; i < 501; i++) DeleteOp('clubs/c1/attempts/a$i'),
      ]),
    );

    await expectLater(
      store.commit(commit(after: marker(), creates: true, lot: lot)),
      throwsA(isA<ServiceFailure>()),
    );
    expect(rules.appliedBatches, 0);
  });

  test('own markers lists the ones of the account only', () async {
    server
      ..seed('clubs/c1/operations/${key}_u-dir', {
        'createdBy': 'u-dir',
        'kind': 'erasure',
        'operationId': key,
        'done': 1,
        'stage': 0,
        'role': 'director',
      })
      ..seed('clubs/c1/operations/${key}_u-admin', {
        'createdBy': 'u-admin',
        'kind': 'erasure',
        'operationId': key,
        'done': 1,
        'stage': 0,
        'role': 'admin',
      });

    final own = await store.ownMarkers();

    expect(own, hasLength(1));
    expect(own.single.role, Role.director);
  });

  test('without an account, nothing is read or written', () async {
    final anonymous = SessionScope();
    final nobody = FirestoreOperationStore(
      ClubStore(rules, anonymous),
      anonymous,
    );

    await expectLater(nobody.readMarker(key), throwsA(isA<ServiceFailure>()));
    await expectLater(
      nobody.commit(commit(after: marker(), creates: true)),
      throwsA(isA<ServiceFailure>()),
    );
  });
}
