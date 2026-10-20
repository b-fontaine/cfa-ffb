import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> aucuneEcritureNaEteFaite(WidgetTester tester) async {
  expect(ImportWorld.current.store.appliedBatches, 0);
  final world = ImportWorld.current;
  expect(world.server.documents.keys.toSet(), world.seeded.keys.toSet());
}
