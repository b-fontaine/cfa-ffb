import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the illustration is marked as a proposal
Future<void> theIllustrationIsMarkedAsAProposal(WidgetTester tester) async {
  expect(find.byType(ProposalBadge), findsOneWidget);
}
