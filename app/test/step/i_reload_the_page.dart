import 'package:flutter_test/flutter_test.dart';

import '../support/relaunch.dart';

/// Usage: I reload the page
///
/// Rechargement de la page web : comme `I relaunch the app`, mais la barre
/// d'adresse garde l'adresse courante, qui est rouverte.
Future<void> iReloadThePage(WidgetTester tester) =>
    relaunchApp(tester, address: currentAddress(tester));
