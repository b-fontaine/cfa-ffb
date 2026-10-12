import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'Léa'} has validated the block {'puissance'}
Future<void> hasValidatedTheBlock(
  WidgetTester tester,
  String name,
  String block,
) => UiWorld.seedValidatedBlock(tester, name, block);
