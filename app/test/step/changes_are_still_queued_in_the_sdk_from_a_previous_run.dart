import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: changes are still queued in the SDK from a previous run
///
/// Des écritures faites hors ligne avant la fermeture de l'application
/// attendent toujours dans le cache persistant du SDK : le compteur en
/// mémoire de cette vie de l'application n'en sait rien.
Future<void> changesAreStillQueuedInTheSdkFromAPreviousRun(
  WidgetTester tester,
) async {
  await UiWorld.prepare(tester);
  UiWorld.sdkQueue.hold();
}
