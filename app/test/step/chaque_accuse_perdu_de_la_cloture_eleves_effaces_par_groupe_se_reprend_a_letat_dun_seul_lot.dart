import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void>
chaqueAccusePerduDeLaClotureElevesEffacesParGroupeSeReprendALetatDunSeulLot(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world.toErase = world.seeded!.firstOfEach(count.toInt());
  final reference = await world.oneShotReference(
    prepareNext: true,
    dropPlanned: true,
  );
  final whole = await world.freshReference();
  whole.toErase = whole.seeded!.firstOfEach(count.toInt());
  await whole.close();
  final lots = whole.store.appliedBatches;
  for (var lost = 0; lost < lots; lost++) {
    final run = await world.freshReference();
    run.toErase = run.seeded!.firstOfEach(count.toInt());
    run.store.dropAckAt = lost;
    final first = await run.close();
    expect(
      run.closureOutcome(first).status,
      OperationRunStatus.interrupted,
      reason: 'accusé du lot $lost perdu',
    );
    run.store.dropAckAt = null;
    if (await run.hasPendingClosure()) {
      await run.resumeFound();
      expect(
        run.closureOutcome().status,
        OperationRunStatus.completed,
        reason: 'reprise après accusé du lot $lost perdu',
      );
    }
    expect(await run.state(), reference, reason: 'accusé du lot $lost perdu');
    expect(run.markers(), isEmpty, reason: 'accusé du lot $lost perdu');
  }
}
