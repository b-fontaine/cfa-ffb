import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leClubEstIdentiqueACeluiDunImportComplet(
  WidgetTester tester,
) async {
  final world = ImportWorld.current;
  final reference = await world.referenceImport();
  expect(world.clubDocuments(), reference);
  final marker = world.marker()!;
  expect(marker['done'], marker['lots']);
}
