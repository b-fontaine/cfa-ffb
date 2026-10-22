import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/lib/operations/operation_plan.dart';
import 'package:billard_cfa/shared/lib/operations/operation_store.dart';
import 'package:billard_cfa/shared/lib/operations/unsupported_operations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Matcher unsupported() => throwsA(
    isA<ServiceFailure>().having(
      (f) => f.code,
      'code',
      ServiceFailureCode.unsupported,
    ),
  );

  test(
    'the store of a build on drift refuses everything, writing nothing',
    () async {
      const store = UnsupportedOperationStore();

      await expectLater(store.readMarker('k'), unsupported());
      await expectLater(store.ownMarkers(), unsupported());
      await expectLater(
        store.commit(
          OperationLotCommit(
            lot: OperationLot.empty,
            marker: const OperationMarker(
              key: 'k',
              kind: OperationKind.erasure,
              done: 1,
              stage: 0,
              role: Role.director,
            ),
            createsMarker: true,
            finishes: false,
          ),
        ),
        unsupported(),
      );
    },
  );

  test('the purge of a build on drift refuses everything', () async {
    const purge = UnsupportedStudentPurge();
    const id = StudentId('s1');

    await expectLater(purge.preview(id), unsupported());
    await expectLater(purge.exists(id), unsupported());
    await expectLater(purge.flagged(), unsupported());
    await expectLater(purge.purgeLots({id}, maxWrites: 3), unsupported());
    expect(() => purge.flag({id}), unsupported());
    expect(() => purge.removeRecords({id}), unsupported());
  });
}
