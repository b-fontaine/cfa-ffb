import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leCompteConnecteEstUnEnseignantDuGroupe(
  WidgetTester tester,
  String groupName,
) async {
  final world = OperationsWorld.current;
  world.scope.activate(
    OperationsWorld.clubId,
    Role.teacher,
    groupIds: [GroupId('g-${groupName.toLowerCase()}')],
  );
}
