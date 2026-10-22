import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leClubEstIdentiqueACeluiDunEffacementSansCoupure(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  final reference = await world.freshReference();
  final result = await reference.erasure.erase(
    OperationsWorld.studentId(world.lastErased!),
  );
  expect(reference.erasureOutcome(result).status, OperationRunStatus.completed);
  expect(world.clubDocuments(), reference.clubDocuments());
}
