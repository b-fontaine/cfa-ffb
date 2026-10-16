import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the presentation is drawn over the cloth pattern
///
/// Le motif est le premier enfant de la pile (donc peint en premier), couvre
/// toute la pile, et la présentation vient après lui.
Future<void> thePresentationIsDrawnOverTheClothPattern(
  WidgetTester tester,
) async {
  final cloth = find.byKey(const ValueKey('presentation-cloth'));
  expect(cloth, findsOneWidget, reason: 'le motif de tapis est absent');
  final stackFinder = find
      .ancestor(of: cloth, matching: find.byType(Stack))
      .first;
  final stack = tester.widget<Stack>(stackFinder);
  final first = stack.children.first;
  expect(
    first is Positioned &&
        first.child.key == const ValueKey('presentation-cloth'),
    isTrue,
    reason: 'le motif doit être peint avant le reste de la présentation',
  );
  expect(stack.children.length, greaterThan(1));
  expect(tester.getRect(cloth), tester.getRect(stackFinder));
}
