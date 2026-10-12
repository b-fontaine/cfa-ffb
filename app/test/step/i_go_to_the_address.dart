import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Usage: I go to the address {'/exercises/puissance/abc'}
Future<void> iGoToTheAddress(WidgetTester tester, String address) async {
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).go(address);
  await tester.pumpAndSettle();
}
