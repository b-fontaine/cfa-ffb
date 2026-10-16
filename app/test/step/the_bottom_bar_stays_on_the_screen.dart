import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the bottom bar stays on the screen
///
/// La barre basse et l'en-tête tiennent dans l'écran, sans débordement.
Future<void> theBottomBarStaysOnTheScreen(WidgetTester tester) async {
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final key in const ['guide-header', 'guide-bottom-bar']) {
    final rect = tester.getRect(find.byKey(ValueKey(key)));
    expect(rect.left, greaterThanOrEqualTo(-0.5), reason: key);
    expect(rect.right, lessThanOrEqualTo(screen.width + 0.5), reason: key);
    expect(rect.top, greaterThanOrEqualTo(-0.5), reason: key);
    expect(rect.bottom, lessThanOrEqualTo(screen.height + 0.5), reason: key);
  }
}
