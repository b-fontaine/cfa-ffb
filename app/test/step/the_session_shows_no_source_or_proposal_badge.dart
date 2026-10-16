import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the session {'posture-1'} shows no source or proposal badge
///
/// Une ligne ne porte ni badge « Proposition » ni badge de source : seulement
/// le badge de relecture et les badges neutres des propositions mineures.
Future<void> theSessionShowsNoSourceOrProposalBadge(
  WidgetTester tester,
  String id,
) async {
  final tile = find.byKey(ValueKey('sheet:$id'));
  expect(tile, findsOneWidget);
  expect(
    find.descendant(of: tile, matching: find.byType(ProposalBadge)),
    findsNothing,
  );
  expect(
    find.descendant(of: tile, matching: find.byType(ProvenanceBadge)),
    findsNothing,
  );
}
