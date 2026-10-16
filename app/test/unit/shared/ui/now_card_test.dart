import 'package:billard_cfa/shared/ui/now_card.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

NowCard card({
  VoidCallback? onPrimary,
  VoidCallback? onSecondary,
  SectionEmphasis emphasis = SectionEmphasis.medium,
  bool withActions = true,
}) => NowCard(
  stateLabel: 'Next',
  stateIcon: Icons.event,
  title: 'Posture, session 1/1',
  meta: const ['Mon, Oct 19', 'Group'],
  emphasis: emphasis,
  primaryLabel: withActions ? 'Launch' : null,
  onPrimary: onPrimary,
  secondaryLabel: withActions ? 'Prepare' : null,
  onSecondary: onSecondary,
);

void main() {
  testWidgets('shows the state, the title and the meta lines', (tester) async {
    await pumpUi(tester, card());

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Posture, session 1/1'), findsOneWidget);
    expect(find.text('Mon, Oct 19'), findsOneWidget);
    expect(find.text('Group'), findsOneWidget);
  });

  testWidgets('calls the primary and secondary actions', (tester) async {
    var primary = 0;
    var secondary = 0;
    await pumpUi(
      tester,
      card(onPrimary: () => primary++, onSecondary: () => secondary++),
    );

    await tester.tap(find.text('Launch'));
    await tester.tap(find.text('Prepare'));

    expect((primary, secondary), (1, 1));
  });

  testWidgets('has actions at least 48 dp high', (tester) async {
    await pumpUi(tester, card(onPrimary: () {}, onSecondary: () {}));

    for (final label in ['Launch', 'Prepare']) {
      final size = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('shows no action when none is given', (tester) async {
    await pumpUi(tester, card(withActions: false));

    expect(find.byType(ButtonStyleButton), findsNothing);
  });

  testWidgets('announces state and title as one group', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, card(onPrimary: () {}, onSecondary: () {}));

    expect(
      find.bySemanticsLabel(RegExp('Next.*Posture, session 1/1')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('takes the cloth-blue border when emphasised', (tester) async {
    await pumpUi(tester, card(emphasis: SectionEmphasis.high));

    final shape =
        tester.widget<Card>(find.byType(Card)).shape! as RoundedRectangleBorder;
    final scheme = Theme.of(tester.element(find.byType(Card))).colorScheme;
    expect(shape.side.color, scheme.secondary);
    expect(shape.side.width, 2);
  });
}
