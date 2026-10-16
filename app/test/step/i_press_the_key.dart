import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I press the key {'F'}
///
/// Une lettre du clavier, relâchée aussitôt.
Future<void> iPressTheKey(WidgetTester tester, String key) async {
  final logical = switch (key) {
    'F' => LogicalKeyboardKey.keyF,
    _ => throw ArgumentError('touche inconnue : $key'),
  };
  await tester.sendKeyEvent(logical);
  await tester.pumpAndSettle();
}
