import 'package:flutter_test/flutter_test.dart';

/// Usage: the player controls are visible on the screen
///
/// Lecture, rejouer et vitesse sont dans l'écran, au-dessus de la barre basse,
/// sans défiler.
Future<void> thePlayerControlsAreVisibleOnTheScreen(WidgetTester tester) async {
  final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final label in ['Play', 'Replay', 'Speed ×1']) {
    final control = find.text(label);
    expect(control, findsOneWidget, reason: 'commande « $label » absente');
    final rect = tester.getRect(control);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(screen.height));
  }
}
