import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> nexistePlusDansLeClub(WidgetTester tester, String name) async {
  final world = OperationsWorld.current;
  expect(
    world.doc('clubs/c1/students/${OperationsWorld.idOf(name)}'),
    isNull,
    reason: 'la fiche est supprimée',
  );
}
