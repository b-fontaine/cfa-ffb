import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('says Proposal in English, with an icon beside the text', (
    tester,
  ) async {
    await pumpUi(tester, const ProposalBadge());

    expect(find.text('Proposal'), findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsOneWidget);
  });

  testWidgets('says Proposition in French', (tester) async {
    await pumpUi(tester, const ProposalBadge(), locale: const Locale('fr'));

    expect(find.text('Proposition'), findsOneWidget);
  });

  testWidgets('is readable by a screen reader through its text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const ProposalBadge());

    expect(find.bySemanticsLabel('Proposal'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('uses the container colours of the theme, text on top', (
    tester,
  ) async {
    await pumpUi(tester, const ProposalBadge());

    final scheme = Theme.of(tester.element(find.byType(ProposalBadge)))
        .colorScheme;
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(ProposalBadge),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, scheme.tertiaryContainer);
  });
}
