import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the provenance badges are {'hidden'}
///
/// Mode Mener : aucun badge de provenance ni de proposition affiché. Pour le
/// mode Relecture, voir `I see {n} provenance badges and {m} proposal badges`.
Future<void> theProvenanceBadgesAre(WidgetTester tester, String state) async {
  if (state != 'hidden') throw ArgumentError('état inconnu : $state');
  expect(find.byType(ProvenanceBadge), findsNothing);
  expect(find.byType(ProposalBadge), findsNothing);
}
