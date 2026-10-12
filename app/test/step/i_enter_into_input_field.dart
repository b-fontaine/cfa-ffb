import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Example: When I enter {'text'} into {1} input field
Future<void> iEnterIntoInputField(
  WidgetTester tester,
  String text,
  int index,
) async {
  await tester.enterText(find.byType(TextField).at(index), text);
  await tester.pumpAndSettle();
}
