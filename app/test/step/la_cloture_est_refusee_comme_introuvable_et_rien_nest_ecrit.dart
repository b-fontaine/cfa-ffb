import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laClotureEstRefuseeCommeIntrouvableEtRienNestEcrit(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  final result = world.closureResult;
  expect(result, isA<Err<Object?>>(), reason: '$result');
  expect((result! as Err<Object?>).failure, isA<NotFound>());
  expect(world.store.appliedBatches, world.batchesMark);
}
