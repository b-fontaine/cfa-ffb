import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
///
/// Marque le bloc acquis par le vrai cas d'usage (jamais de passage fictif).
Future<void> hasTheBlockAcquiredOn(
  WidgetTester tester,
  String name,
  String block,
  String date,
) => UiWorld.seedAcquired(tester, name, block, DateTime.parse(date));
