import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leffacementEstRefuseEtRienNestEcrit(WidgetTester tester) async {
  final world = OperationsWorld.current;
  final result = world.erasureResult;
  expect(result, isA<Err<Object?>>());
  final failure = (result! as Err<Object?>).failure;
  expect(failure, isA<ServiceFailure>());
  expect((failure as ServiceFailure).code, ServiceFailureCode.denied);
  expect(world.store.appliedBatches, world.batchesMark);
  expect(world.markers(), isEmpty);
}
