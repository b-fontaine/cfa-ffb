import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laClotureEstRefuseeAvecLeMotifEtRienNestEcrit(
  WidgetTester tester,
  String code,
) async {
  final world = OperationsWorld.current;
  final result = world.closureResult;
  expect(result, isA<Err<Object?>>(), reason: '$result');
  final failure = (result! as Err<Object?>).failure;
  expect(failure, isA<InvariantViolation>());
  expect((failure as InvariantViolation).code.name, code);
  expect(world.store.appliedBatches, world.batchesMark);
  expect(world.markers(), isEmpty);
}
