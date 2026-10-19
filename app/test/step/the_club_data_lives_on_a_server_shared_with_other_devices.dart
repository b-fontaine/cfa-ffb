import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the club data lives on a server shared with other devices
///
/// Les données du club sont sur un serveur que partagent plusieurs appareils
/// (FB5b) : l'application utilise les dépôts Firestore, et un autre appareil
/// du même club (directeur) écrit sur le même serveur. Les étapes d'amorçage
/// qui suivent (`the club has the student`, `has … successful passes`,
/// `a session … is planned`) passent par cet autre appareil, et ce qu'il
/// écrit arrive à l'écran par les flux, sans recharger.
Future<void> theClubDataLivesOnAServerSharedWithOtherDevices(
  WidgetTester tester,
) => UiWorld.shareServer(tester);
