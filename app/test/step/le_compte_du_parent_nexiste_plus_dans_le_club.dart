import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leCompteDuParentNexistePlusDansLeClub(WidgetTester tester) async {
  expect(
    OperationsWorld.current.doc('clubs/c1/members/u-parent'),
    isNull,
    reason:
        'le compte du parent (son nom affiché) est une donnée de la personne',
  );
}
