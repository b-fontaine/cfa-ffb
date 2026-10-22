import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void>
leffacementEstSuspenduPourAujourdhuiEtLaFicheDeEstMarqueeEnCoursDeffacement(
  WidgetTester tester,
  String name,
) async {
  final world = OperationsWorld.current;
  expect(world.erasureOutcome().status, OperationRunStatus.paused);
  expect(
    world.doc('clubs/c1/students/${OperationsWorld.idOf(name)}')!['erasing'],
    isTrue,
  );
}
