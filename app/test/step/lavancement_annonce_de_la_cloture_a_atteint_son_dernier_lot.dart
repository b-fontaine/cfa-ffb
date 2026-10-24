import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> lavancementAnnonceDeLaClotureAAtteintSonDernierLot(
  WidgetTester tester,
) async {
  final progress = OperationsWorld.current.lastProgress;
  expect(progress, isNotNull, reason: 'aucun avancement annoncé');
  final (done, total) = progress!;
  expect(total, greaterThan(0));
  expect(done, total);
}
