import 'package:billard_cfa/features/backup_data/domain/club_import/club_import_runner.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leDirecteurImporteLaSauvegardeMaisLaConnexionEstCoupeeApresLots(
  WidgetTester tester,
  num lots,
) async {
  final world = ImportWorld.current..act(Role.director);
  world.decisions = world.createAll();
  await world.prepare();
  world.store.failAfterBatches = lots.toInt();
  final run = await world.runPlan();
  expect(run.status, ImportRunStatus.interrupted);
  expect(run.doneLots, lots.toInt());
}
