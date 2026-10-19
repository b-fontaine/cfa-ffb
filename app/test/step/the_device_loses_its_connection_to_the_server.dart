import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the device loses its connection to the server
///
/// L'appareil de l'écran perd le serveur ; les autres appareils continuent
/// d'écrire. Ses lectures échouent hors ligne et ses flux cessent de livrer.
Future<void> theDeviceLosesItsConnectionToTheServer(WidgetTester tester) async {
  UiWorld.device.goOffline();
  await tester.pumpAndSettle();
}
