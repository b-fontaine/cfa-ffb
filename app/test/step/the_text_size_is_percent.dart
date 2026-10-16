import 'package:flutter_test/flutter_test.dart';

/// Usage: the text size is {200} percent
///
/// Réglage système de taille du texte, rétabli à la fin du scénario.
Future<void> theTextSizeIsPercent(WidgetTester tester, num percent) async {
  tester.platformDispatcher.textScaleFactorTestValue = percent / 100;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
