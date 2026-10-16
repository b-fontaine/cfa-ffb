import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/ui_world.dart';

/// Usage: I go to the address of the showcase of {'Léa'}
Future<void> iGoToTheAddressOfTheShowcaseOf(
  WidgetTester tester,
  String name,
) async {
  final student = await UiWorld.studentNamed(name);
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go('/students/${student.id.value}/show');
  await tester.pumpAndSettle();
}
