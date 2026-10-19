import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the device gets its connection to the server back
///
/// L'appareil retrouve le serveur : ses flux reçoivent l'état courant et
/// l'écran se met à jour sans rechargement.
Future<void> theDeviceGetsItsConnectionToTheServerBack(
  WidgetTester tester,
) async {
  await tester.runAsync(UiWorld.device.goOnline);
  await UiWorld.settle(tester);
}
