import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the selected navigation destination uses the cloth blue container
Future<void> theSelectedNavigationDestinationUsesTheClothBlueContainer(
  WidgetTester tester,
) async {
  final context = tester.element(find.byType(Scaffold).first);
  final container = Theme.of(context).colorScheme.secondaryContainer;
  // Valeur littérale attendue par thème (famille bleu-tapis, jamais le rose).
  final isDark = Theme.of(context).brightness == Brightness.dark;
  expect(container, isDark ? const Color(0xFF1F5873) : const Color(0xFFCFE6F3));

  final indicators = tester.widgetList<NavigationIndicator>(
    find.byType(NavigationIndicator),
  );
  expect(indicators, isNotEmpty);
  expect(indicators.every((indicator) => indicator.color == container), isTrue);
}
