import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> leSecondEffacementEstRefuseCommeIntrouvable(
  WidgetTester tester,
) async {
  final result = OperationsWorld.current.erasureResult;
  expect(result, isA<Err<Object?>>());
  expect((result! as Err<Object?>).failure, isA<NotFound>());
}
