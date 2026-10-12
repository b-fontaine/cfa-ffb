import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see the {'bar'} navigation
Future<void> iSeeTheNavigation(WidgetTester tester, String kind) async {
  expect(
    find.byType(NavigationBar),
    kind == 'bar' ? findsOneWidget : findsNothing,
  );
  expect(
    find.byType(NavigationRail),
    kind == 'rail' ? findsOneWidget : findsNothing,
  );
}
