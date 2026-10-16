import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the menu of the group {'Children group'}
Future<void> iOpenTheMenuOfTheGroup(WidgetTester tester, String group) async {
  final menu = find.byTooltip('Actions for group $group');
  expect(menu, findsOneWidget, reason: 'aucun menu pour le groupe : $group');
  await tester.ensureVisible(menu);
  await tester.pumpAndSettle();
  await tester.tap(menu);
  await tester.pumpAndSettle();
}
