import 'package:flutter_test/flutter_test.dart';

import '../support/relaunch.dart';

/// Usage: I relaunch the app
///
/// Ferme l'application et la rouvre sur l'accueil : la mémoire des séances
/// guidées est perdue, les données de l'appareil restent et le démarrage
/// remet en place les séances guidées en cours.
Future<void> iRelaunchTheApp(WidgetTester tester) => relaunchApp(tester);
