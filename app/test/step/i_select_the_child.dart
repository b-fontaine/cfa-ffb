import 'package:billard_cfa/features/student_showcase/presentation/ui/family_space_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I select the child {'Tom'}
Future<void> iSelectTheChild(WidgetTester tester, String name) async {
  final chip = find.descendant(
    of: find.byType(ChildSelector),
    matching: find.widgetWithText(ChoiceChip, name),
  );
  await tester.tap(chip);
  await tester.pumpAndSettle();
}
