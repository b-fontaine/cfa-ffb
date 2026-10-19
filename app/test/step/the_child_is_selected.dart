import 'package:billard_cfa/features/student_showcase/presentation/ui/family_space_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the child {'Tom'} is selected
Future<void> theChildIsSelected(WidgetTester tester, String name) async {
  final chip = find.descendant(
    of: find.byType(ChildSelector),
    matching: find.widgetWithText(ChoiceChip, name),
  );
  expect(chip, findsOneWidget);
  expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
}
