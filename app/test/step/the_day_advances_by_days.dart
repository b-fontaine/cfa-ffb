import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the day advances by {1} days
///
/// Fait avancer l'horloge figée du scénario, sans reconstruire la page ouverte.
Future<void> theDayAdvancesByDays(WidgetTester tester, num days) async {
  UiWorld.advanceDays(days.toInt());
}
