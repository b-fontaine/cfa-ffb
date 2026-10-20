import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leDirecteurPrepareANouveauLimportDuMemeFichier(
  WidgetTester tester,
) async {
  final world = ImportWorld.current;
  world.batchesBeforeSecondPrepare = world.store.appliedBatches;
  await world.prepare();
}
