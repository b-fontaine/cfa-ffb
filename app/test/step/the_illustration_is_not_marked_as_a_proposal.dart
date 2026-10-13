import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the illustration is not marked as a proposal
Future<void> theIllustrationIsNotMarkedAsAProposal(WidgetTester tester) async {
  expect(find.byType(ProposalBadge), findsNothing);
}
