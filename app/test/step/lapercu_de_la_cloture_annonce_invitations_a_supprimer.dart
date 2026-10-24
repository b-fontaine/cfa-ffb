import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> lapercuDeLaClotureAnnonceInvitationsASupprimer(
  WidgetTester tester,
  num count,
) async {
  final world = OperationsWorld.current;
  world.batchesMark = world.store.appliedBatches;
  final result = await world.closing.invitationsToPurge();
  expect(result, isA<Ok<int>>(), reason: '$result');
  expect((result as Ok<int>).value, count.toInt());
}
