import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> larchiveEstEcriteAvantLePremierEffacementDeDonneeDeleve(
  WidgetTester tester,
) async {
  final log = OperationsWorld.current.store.log;
  final archive = log.indexWhere((b) => b.any((p) => p.contains('/archives/')));
  final erasure = log.indexWhere((b) => b.any((p) => p.contains('/attempts/')));
  expect(archive, isNonNegative);
  expect(erasure, isNonNegative);
  expect(archive, lessThan(erasure));
}
