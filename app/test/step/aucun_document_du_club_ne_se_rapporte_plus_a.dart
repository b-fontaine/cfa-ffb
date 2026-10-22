import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> aucunDocumentDuClubNeSeRapportePlusA(
  WidgetTester tester,
  String name,
) async {
  expect(OperationsWorld.current.documentsAbout(name), isEmpty);
}
