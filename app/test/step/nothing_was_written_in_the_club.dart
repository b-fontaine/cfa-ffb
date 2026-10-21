import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

/// Usage: nothing was written in the club
Future<void> nothingWasWrittenInTheClub(WidgetTester tester) async {
  final world = ImportWorld.current;
  expect(world.store.appliedBatches, 0);
  expect(world.server.documents.length, world.seeded.length);
}
