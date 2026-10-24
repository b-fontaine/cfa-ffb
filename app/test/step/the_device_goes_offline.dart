import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the device goes offline
///
/// Plus de réseau : le service d'authentification et le serveur des données
/// sont injoignables.
Future<void> theDeviceGoesOffline(WidgetTester tester) async {
  UiWorld.auth.offline = true;
  UiWorld.memberships.unavailable = true;
}
