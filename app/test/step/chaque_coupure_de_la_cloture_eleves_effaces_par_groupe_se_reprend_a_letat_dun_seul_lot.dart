import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void>
chaqueCoupureDeLaClotureElevesEffacesParGroupeSeReprendALetatDunSeulLot(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world.toErase = world.seeded!.firstOfEach(count.toInt());
  final reference = await world.oneShotReference(
    prepareNext: true,
    dropPlanned: true,
  );
  // Une clôture sans coupure donne le nombre de lots à parcourir.
  final whole = await world.freshReference();
  whole.toErase = whole.seeded!.firstOfEach(count.toInt());
  await whole.close();
  final lots = whole.store.appliedBatches;
  expect(lots, greaterThan(5), reason: 'une clôture compte plusieurs lots');
  expect(await whole.state(), reference);
  for (var cut = 0; cut < lots; cut++) {
    final run = await world.freshReference();
    run.toErase = run.seeded!.firstOfEach(count.toInt());
    run.store.failAfterBatches = cut;
    final first = await run.close();
    expect(
      run.closureOutcome(first).status,
      OperationRunStatus.interrupted,
      reason: 'coupure après $cut lots',
    );
    run.store.failAfterBatches = null;
    if (await run.hasPendingClosure()) {
      await run.resumeFound();
    } else {
      // Rien n'a été écrit : l'animateur recommence la clôture.
      expect(cut, 0);
      await run.close();
    }
    expect(
      run.closureOutcome().status,
      OperationRunStatus.completed,
      reason: 'reprise après $cut lots',
    );
    expect(await run.state(), reference, reason: 'coupure après $cut lots');
    expect(run.markers(), isEmpty, reason: 'coupure après $cut lots');
  }
}
