import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'Léa'} has recorded the passes {'6 of 9, 8 of 9'} on {'puissance 1'}
///
/// Les passages d'une même séance (le 12 septembre), dans l'ordre donné : le
/// rang de chacun se dérive de cet ordre d'enregistrement (ADR 0024,
/// décision 17).
Future<void> hasRecordedThePassesOn(
  WidgetTester tester,
  String name,
  String scores,
  String exercise,
) => UiWorld.seedPassesInOneSession(tester, name, UiWorld.exercise(exercise), [
  for (final score in scores.split(','))
    int.parse(score.trim().split(' ').first),
]);
