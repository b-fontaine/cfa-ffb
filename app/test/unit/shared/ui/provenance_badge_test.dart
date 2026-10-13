import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('names the federal source in English', (tester) async {
    await pumpUi(tester, const ProvenanceBadge(provenance: Provenance.s));

    expect(find.text('Federal source'), findsOneWidget);
    expect(find.byType(ProposalBadge), findsNothing);
  });

  testWidgets('names each source in French', (tester) async {
    const fr = Locale('fr');
    await pumpUi(
      tester,
      const Column(
        children: [
          ProvenanceBadge(provenance: Provenance.s),
          ProvenanceBadge(provenance: Provenance.ffb),
          ProvenanceBadge(provenance: Provenance.web),
        ],
      ),
      locale: fr,
    );

    expect(find.text('Source fédérale'), findsOneWidget);
    expect(find.text('Site ffbillard.com'), findsOneWidget);
    expect(find.text('Autre site'), findsOneWidget);
  });

  testWidgets('shows the Proposal badge for a proposal, never a source', (
    tester,
  ) async {
    await pumpUi(tester, const ProvenanceBadge(provenance: Provenance.prop));

    expect(find.byType(ProposalBadge), findsOneWidget);
    expect(find.text('Federal source'), findsNothing);
  });

  testWidgets('carries its meaning in text, with a decorative icon', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const ProvenanceBadge(provenance: Provenance.web));

    expect(find.bySemanticsLabel('Other website'), findsOneWidget);
    handle.dispose();
  });

  test('labels every provenance, [Prop] included', () {
    // sourceLabel est total sur l'énumération (switch exhaustif).
    expect(Provenance.values, hasLength(4));
  });
}
