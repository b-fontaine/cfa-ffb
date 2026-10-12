import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the {'dark'} theme is used
Future<void> theThemeIsUsed(WidgetTester tester, String theme) async {
  final expected = theme == 'dark' ? Brightness.dark : Brightness.light;
  final context = tester.element(find.byType(Scaffold).first);
  expect(Theme.of(context).brightness, expected);
}
