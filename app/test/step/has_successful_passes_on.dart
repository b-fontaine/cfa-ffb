import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'Léa'} has {5} successful passes on {'puissance 1'}
Future<void> hasSuccessfulPassesOn(
  WidgetTester tester,
  String name,
  num count,
  String exercise,
) => UiWorld.seedPasses(
  tester,
  name,
  UiWorld.exercise(exercise),
  count.toInt(),
  passed: true,
);
