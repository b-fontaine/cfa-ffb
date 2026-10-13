import 'package:billard_cfa/entities/session_sheet/presentation/sheet_illustration_view.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../shared/ui/pump_ui.dart';

const _illustration = Illustration.contact(
  id: 'c',
  caption: 'Demi-bille : la blanche couvre la moitié.',
  alt: 'La blanche couvre la moitié de la bille.',
  fraction: ContactFraction.half,
  tipPoint: TipPoint.center,
);

void main() {
  testWidgets('shows the figure and its caption', (tester) async {
    await pumpUi(
      tester,
      const SheetIllustrationView(illustration: _illustration, diagrams: {}),
    );

    expect(find.byType(BallContactDiagram), findsOneWidget);
    expect(
      find.text('Demi-bille : la blanche couvre la moitié.'),
      findsOneWidget,
    );
    expect(find.byType(ProposalBadge), findsNothing);
  });

  testWidgets('carries the Proposal badge of the element that cites it', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const SheetIllustrationView(
        illustration: _illustration,
        diagrams: {},
        proposal: true,
      ),
    );

    expect(find.byType(ProposalBadge), findsOneWidget);
  });

  testWidgets('leaves the caption to the caller when asked', (tester) async {
    await pumpUi(
      tester,
      const SheetIllustrationView(
        illustration: _illustration,
        diagrams: {},
        showCaption: false,
        proposal: true,
      ),
    );

    expect(
      find.text('Demi-bille : la blanche couvre la moitié.'),
      findsNothing,
    );
    expect(find.byType(ProposalBadge), findsOneWidget);
  });

  testWidgets('is wider under the presentation scope', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpUi(
      tester,
      const SheetIllustrationView(illustration: _illustration, diagrams: {}),
    );
    final normal = tester.getSize(find.byType(BallContactDiagram)).width;

    await pumpUi(
      tester,
      const PresentationScope(
        child: SheetIllustrationView(illustration: _illustration, diagrams: {}),
      ),
    );
    final presented = tester.getSize(find.byType(BallContactDiagram)).width;

    expect(normal, lessThanOrEqualTo(SheetIllustrationView.maxWidth));
    expect(presented, greaterThan(normal));
  });
}
