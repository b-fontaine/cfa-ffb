import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laFicheDeEstSupprimeeApresToutesSesDonnees(
  WidgetTester tester,
  String name,
) async {
  final log = OperationsWorld.current.store.log;
  final fiche = 'clubs/c1/students/${OperationsWorld.idOf(name)}';
  final suffix = OperationsWorld.idOf(name).substring(2);
  var lastFiche = -1;
  var lastOther = -1;
  var lastLink = -1;
  for (var i = 0; i < log.length; i++) {
    for (final path in log[i]) {
      if (path == fiche) lastFiche = i;
      if (path != fiche && path.contains('-$suffix')) lastOther = i;
      if (path.contains('/members/') || path.contains('/records/')) {
        lastLink = i;
      }
    }
  }
  expect(lastFiche, greaterThan(lastOther), reason: 'données puis fiche');
  expect(lastFiche, greaterThan(lastLink), reason: 'liens puis fiche');
}
