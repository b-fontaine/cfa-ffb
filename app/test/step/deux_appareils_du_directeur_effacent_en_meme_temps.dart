import 'package:billard_cfa/features/manage_students/domain/club_student_erasure.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> deuxAppareilsDuDirecteurEffacentEnMemeTemps(
  WidgetTester tester,
  String name,
) async {
  final world = OperationsWorld.current;
  world
    ..batchesMark = world.store.appliedBatches
    ..lastErased = name;
  // Chaque lot cède la main : les deux appareils s'entrelacent lot par lot.
  world.store.beforeCommit = () async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.value();
    }
  };
  final id = OperationsWorld.studentId(name);
  final results = await Future.wait([
    world.erasure.erase(id),
    ClubStudentErasure(
      world.secondDevice(),
      world.purge,
      world.scope,
    ).erase(id),
  ]);
  world.store.beforeCommit = null;
  for (final result in results) {
    expect(world.erasureOutcome(result).status, OperationRunStatus.completed);
  }
}
