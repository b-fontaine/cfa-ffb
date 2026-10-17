import 'package:billard_cfa/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Démarre l'application à froid sur [address] (un lien ouvert dans le
/// navigateur) : l'état de session est inconnu au premier calcul de la route.
///
/// Usage: the app is opened on the address {'/join/ABCDEFGHJKMN'}
Future<void> theAppIsOpenedOnTheAddress(
  WidgetTester tester,
  String address,
) async {
  tester.platformDispatcher.defaultRouteNameTestValue = address;
  addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  await UiWorld.prepare(tester);
  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();
}
