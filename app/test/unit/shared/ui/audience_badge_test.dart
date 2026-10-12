import 'package:billard_cfa/shared/ui/audience_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('labels the children audience with an icon', (tester) async {
    await pumpUi(tester, const AudienceBadge(kind: AudienceKind.children));

    expect(find.text('Children'), findsOneWidget);
    expect(find.byIcon(Icons.child_care), findsOneWidget);
  });

  testWidgets('labels the adults audience with an icon', (tester) async {
    await pumpUi(tester, const AudienceBadge(kind: AudienceKind.adults));

    expect(find.text('Adults'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('is localized', (tester) async {
    await pumpUi(
      tester,
      const AudienceBadge(kind: AudienceKind.adults),
      locale: const Locale('fr'),
    );

    expect(find.text('Adultes'), findsOneWidget);
  });

  testWidgets('uses different containers for the two audiences', (
    tester,
  ) async {
    Color? background() {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AudienceBadge),
          matching: find.byType(DecoratedBox),
        ),
      );
      return (box.decoration as BoxDecoration).color;
    }

    await pumpUi(tester, const AudienceBadge(kind: AudienceKind.children));
    final children = background();
    await pumpUi(tester, const AudienceBadge(kind: AudienceKind.adults));

    expect(children, isNot(background()));
  });
}
