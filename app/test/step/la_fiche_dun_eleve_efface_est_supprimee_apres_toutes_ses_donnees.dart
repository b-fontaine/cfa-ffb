import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laFicheDunEleveEffaceEstSupprimeeApresToutesSesDonnees(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  final log = world.store.log;
  var firstFicheEnd = log.length;
  var lastPresence = -1;
  for (var i = 0; i < log.length; i++) {
    if (log[i].any((p) => p.contains('/records/'))) lastPresence = i;
  }
  for (final id in world.toErase) {
    final fiche = 'clubs/c1/students/${id.value}';
    final suffix = id.value.substring(2);
    var lastFiche = -1;
    var lastOther = -1;
    for (var i = 0; i < log.length; i++) {
      for (final path in log[i]) {
        if (path == fiche) lastFiche = i;
        if (path != fiche && path.contains('-$suffix')) lastOther = i;
      }
    }
    expect(lastFiche, greaterThan(lastOther), reason: id.value);
    if (lastFiche < firstFicheEnd) firstFicheEnd = lastFiche;
  }
  expect(firstFicheEnd, greaterThan(lastPresence));
}
