import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../contract/unit_of_work_contract.dart';
import '../../../support/firestore_world.dart';

void main() {
  unitOfWorkContract('en mémoire', () async {
    final world = FirestoreWorld()..act('c1', Role.director);
    return (
      club: world.club,
      unitOfWork: FirestoreUnitOfWork(world.club),
      close: () async {},
    );
  });

  group('FirestoreUnitOfWork (double en mémoire)', () {
    late FirestoreWorld world;
    late FirestoreUnitOfWork unit;

    setUp(() {
      world = FirestoreWorld()..act('c1', Role.director);
      unit = FirestoreUnitOfWork(world.club);
    });

    test('sends one single batch for all the writes of the body', () async {
      await unit.run(() async {
        await world.club.commit([
          const SetOp('clubs/c1/students/a', {'n': 1}),
        ]);
        await world.club.commit([
          const SetOp('clubs/c1/students/b', {'n': 2}),
        ]);
        await world.club.commit([const DeleteOp('clubs/c1/students/c')]);
      });

      expect(world.documents.commits, 1);
      expect(world.paths, ['clubs/c1/students/a', 'clubs/c1/students/b']);
    });

    test(
      'a body of more than 500 writes fails before any write (closing a '
      'realistic club is blocked until the resumable batches of FB7)',
      () async {
        Future<void> body() => unit.run(() async {
          for (var i = 0; i < 501; i++) {
            await world.club.commit([
              SetOp('clubs/c1/students/s$i', {'n': i}),
            ]);
          }
        });

        await expectLater(
          body(),
          throwsA(
            isA<ServiceFailure>().having(
              (f) => f.code,
              'code',
              ServiceFailureCode.other,
            ),
          ),
        );
        expect(world.paths, isEmpty);
      },
    );

    test('sends nothing when the body wrote nothing', () async {
      await unit.run(() async {});

      expect(world.documents.commits, 0);
    });

    test('merges two writes of one document into one write', () async {
      await unit.run(() async {
        await world.club.commit([
          const SetOp('clubs/c1/students/a', {
            'firstName': 'Léa',
            'groupIds': ArrayUnion([]),
          }, merge: true),
        ]);
        await world.club.commit([
          const UpdateOp('clubs/c1/students/a', {
            'groupIds': ArrayUnion(['g1']),
          }),
        ]);
        await world.club.commit([
          const UpdateOp('clubs/c1/students/a', {
            'groupIds': ArrayUnion(['g2', 'g1']),
          }),
        ]);
      });

      expect(world.documents.read('clubs/c1/students/a'), {
        'firstName': 'Léa',
        'groupIds': ['g1', 'g2'],
      });
    });

    test('a write then a delete of the same document leaves nothing', () async {
      await unit.run(() async {
        await world.club.commit([
          const SetOp('clubs/c1/students/a', {'n': 1}),
        ]);
        await world.club.commit([const DeleteOp('clubs/c1/students/a')]);
      });

      expect(world.paths, isEmpty);
    });

    test(
      'the club is resolved when the batch is built, not afterwards',
      () async {
        await unit.run(() async {
          await world.club.commit([
            SetOp('${world.club.paths.students}/a', {'n': 1}),
          ]);
          world.act('c2', Role.director);
        });

        expect(world.paths, ['clubs/c1/students/a']);
      },
    );
  });
}
