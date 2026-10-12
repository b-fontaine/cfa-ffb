import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'Théo'} has {3} failed passes on {'puissance 1'}
Future<void> hasFailedPassesOn(
  WidgetTester tester,
  String name,
  num count,
  String exercise,
) => UiWorld.seedPasses(
  tester,
  name,
  UiWorld.exercise(exercise),
  count.toInt(),
  passed: false,
);
