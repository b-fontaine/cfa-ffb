import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I see {3} provenance badges and {1} proposal badges
///
/// Mode Relecture : le nombre exact de badges de provenance et de badges
/// « Proposition » affichés sur l'étape courante.
Future<void> iSeeProvenanceBadgesAndProposalBadges(
  WidgetTester tester,
  int provenance,
  int proposal,
) async {
  expect(find.byType(ProvenanceBadge), findsNWidgets(provenance));
  expect(find.byType(ProposalBadge), findsNWidgets(proposal));
}
