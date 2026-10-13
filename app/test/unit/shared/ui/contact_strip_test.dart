import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/contact_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

const List<ContactFraction> _all = ContactFraction.values;

void main() {
  testWidgets('draws one contact diagram per fraction, in order', (
    tester,
  ) async {
    await pumpUi(tester, const ContactStrip(fractions: _all));

    final diagrams = tester
        .widgetList<BallContactDiagram>(find.byType(BallContactDiagram))
        .toList();
    expect(diagrams.map((d) => d.contact), _all);
  });

  testWidgets('is spoken as one list of fractions, in French', (tester) async {
    await pumpUi(
      tester,
      const ContactStrip(fractions: _all),
      locale: const Locale('fr'),
    );

    expect(
      find.bySemanticsLabel(
        'Les quantités de bille : Bille pleine, Trois-quarts de bille, '
        'Demi-bille, Quart de bille, Finesse',
      ),
      findsOneWidget,
    );
  });

  testWidgets('names the highlighted fraction in English', (tester) async {
    await pumpUi(
      tester,
      const ContactStrip(fractions: _all, highlight: ContactFraction.half),
    );

    expect(
      find.bySemanticsLabel(
        'Ball fractions: Full ball, Three-quarter ball, Half ball, '
        'Quarter ball, Thin cut. Highlighted: Half ball',
      ),
      findsOneWidget,
    );
  });

  testWidgets('marks exactly the highlighted fraction, not by colour only', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const ContactStrip(fractions: _all, highlight: ContactFraction.half),
    );

    final marked = find.byKey(const ValueKey('contact-strip-highlight'));
    expect(marked, findsOneWidget);
    expect(
      find.descendant(of: marked, matching: find.byType(BallContactDiagram)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<BallContactDiagram>(
            find.descendant(
              of: marked,
              matching: find.byType(BallContactDiagram),
            ),
          )
          .contact,
      ContactFraction.half,
    );
    expect(
      find.descendant(of: marked, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
  });

  testWidgets('marks nothing when the highlight is absent from the list', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const ContactStrip(
        fractions: [ContactFraction.full, ContactFraction.half],
        highlight: ContactFraction.quarter,
      ),
    );

    expect(find.byKey(const ValueKey('contact-strip-highlight')), findsNothing);
  });

  testWidgets('wraps into several rows on a narrow width', (tester) async {
    await pumpUi(
      tester,
      const Center(
        child: SizedBox(width: 600, child: ContactStrip(fractions: _all)),
      ),
    );
    final wide = tester.getSize(find.byType(ContactStrip)).height;

    await pumpUi(
      tester,
      const Center(
        child: SizedBox(width: 200, child: ContactStrip(fractions: _all)),
      ),
    );
    final narrow = tester.getSize(find.byType(ContactStrip)).height;

    expect(narrow, greaterThan(wide));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list draws nothing and does not fail', (tester) async {
    await pumpUi(tester, const ContactStrip(fractions: []));

    expect(find.byType(BallContactDiagram), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
