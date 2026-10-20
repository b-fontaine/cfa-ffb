import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> aucuneEcritureNaEteFaiteParCeSecondImport(
  WidgetTester tester,
) async {
  final world = ImportWorld.current;
  expect(world.store.appliedBatches, world.batchesBeforeSecondPrepare);
}
