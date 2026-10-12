import 'package:flutter_test/flutter_test.dart';

/// Example: When I tap {'some'} text
Future<void> iTapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  // Un bouton plus bas que l'écran se fait défiler jusqu'à lui.
  if (finder.evaluate().isNotEmpty) await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
