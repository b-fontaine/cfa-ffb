import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leClubCompteGroupesEtEleves(
  WidgetTester tester,
  num groups,
  num students,
) async {
  final documents = ImportWorld.current.server.documents.keys;
  expect(documents.where((p) => p.contains('/groups/')).length, groups);
  expect(documents.where((p) => p.contains('/students/')).length, students);
}
