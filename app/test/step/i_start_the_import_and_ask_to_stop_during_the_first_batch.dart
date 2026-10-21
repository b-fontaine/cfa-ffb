import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

/// Usage: I start the import and ask to stop during the first batch
Future<void> iStartTheImportAndAskToStopDuringTheFirstBatch(
  WidgetTester tester,
) async {
  // Le serveur répond lentement : l'arrêt est demandé pendant le premier lot.
  final gate = Completer<void>();
  ImportWorld.current.store.beforeCommit = () => gate.future;
  await tester.tap(find.text('Import now'));
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.tap(find.text('Stop after this batch'));
  await tester.pump();
  ImportWorld.current.store.beforeCommit = null;
  gate.complete();
  await tester.pumpAndSettle();
}
