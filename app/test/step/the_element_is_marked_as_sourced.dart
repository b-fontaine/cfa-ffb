import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the element {'game'} is marked as sourced
Future<void> theElementIsMarkedAsSourced(
  WidgetTester tester,
  String element,
) async {
  final holder = find.byKey(ValueKey('source:$element'));
  expect(holder, findsOneWidget, reason: 'élément $element absent');
  expect(
    find.descendant(of: holder, matching: find.byType(ProposalBadge)),
    findsNothing,
  );
  expect(
    find.descendant(of: holder, matching: find.byType(Text)),
    findsOneWidget,
  );
}
