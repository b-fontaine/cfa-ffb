import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leClubComptePassages(WidgetTester tester, num attempts) async {
  final documents = ImportWorld.current.server.documents.keys;
  expect(documents.where((p) => p.contains('/attempts/')).length, attempts);
}
