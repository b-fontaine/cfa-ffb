import 'package:flutter_test/flutter_test.dart';

/// Usage: I tap the tooltip {'Next'}
///
/// Un bouton d'icône se trouve par son infobulle (aussi son nom accessible).
Future<void> iTapTheTooltip(WidgetTester tester, String message) async {
  final finder = find.byTooltip(message);
  expect(finder, findsWidgets, reason: 'aucun bouton « $message »');
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
