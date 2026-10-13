import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the element {'exercise:e1'} is marked as a proposal
Future<void> theElementIsMarkedAsAProposal(
  WidgetTester tester,
  String element,
) async {
  final holder = find.byKey(ValueKey('source:$element'));
  expect(holder, findsOneWidget, reason: 'élément $element absent');
  expect(
    find.descendant(of: holder, matching: find.byType(ProposalBadge)),
    findsOneWidget,
  );
}
