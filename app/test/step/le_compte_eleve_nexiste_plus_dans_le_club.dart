import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leCompteEleveNexistePlusDansLeClub(WidgetTester tester) async {
  expect(
    OperationsWorld.current.doc('clubs/c1/members/u-eleve'),
    isNull,
    reason: "le nom affiché du compte élève est le nom de l'enfant",
  );
}
