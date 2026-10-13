import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I open the session {'demi-bille-2'} of the catalogue
Future<void> iOpenTheSessionOfTheCatalogue(
  WidgetTester tester,
  String id,
) async {
  final tile = find.byKey(ValueKey('sheet:$id'));
  expect(tile, findsOneWidget, reason: 'séance $id absente du catalogue');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}
