import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the number of open subscriptions is the one noted
///
/// Ouvrir puis quitter un écran ne laisse aucune écoute derrière lui.
Future<void> theNumberOfOpenSubscriptionsIsTheOneNoted(
  WidgetTester tester,
) async {
  await UiWorld.settle(tester);
  expect(UiWorld.documents.activeWatchers, UiWorld.notedSubscriptions);
}
