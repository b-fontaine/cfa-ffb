import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('shows its title and content', (tester) async {
    await pumpUi(
      tester,
      const SectionCard(title: 'Skills', child: Text('Content')),
    );

    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('marks the title as a heading for assistive technologies', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(
      tester,
      const SectionCard(title: 'Skills', child: Text('Content')),
    );

    expect(
      tester.getSemantics(find.text('Skills')),
      isSemantics(label: 'Skills', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('is a card', (tester) async {
    await pumpUi(
      tester,
      const SectionCard(title: 'Skills', child: Text('Content')),
    );

    expect(find.byType(Card), findsOneWidget);
  });

  group('emphasis', () {
    Card card(WidgetTester tester) => tester.widget<Card>(find.byType(Card));
    BorderSide side(WidgetTester tester) =>
        (card(tester).shape! as RoundedRectangleBorder).side;
    ColorScheme scheme(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Card))).colorScheme;

    testWidgets('is low by default: content surface, no border', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const SectionCard(title: 'Skills', child: Text('Content')),
      );

      expect(card(tester).color, scheme(tester).surfaceContainerLow);
      expect(side(tester), BorderSide.none);
    });

    testWidgets('medium uses surfaceContainer and an outlineVariant border', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const SectionCard(
          title: 'Skills',
          emphasis: SectionEmphasis.medium,
          child: Text('Content'),
        ),
      );

      expect(card(tester).color, scheme(tester).surfaceContainer);
      expect(side(tester).color, scheme(tester).outlineVariant);
    });

    testWidgets('high uses a cloth-blue border thicker than medium', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const SectionCard(
          title: 'Skills',
          emphasis: SectionEmphasis.high,
          child: Text('Content'),
        ),
      );

      expect(card(tester).color, scheme(tester).surfaceContainer);
      expect(side(tester).color, scheme(tester).secondary);
      expect(side(tester).width, greaterThan(1));
    });

    testWidgets('keeps the title as a heading at every level', (tester) async {
      final handle = tester.ensureSemantics();
      for (final emphasis in SectionEmphasis.values) {
        await pumpUi(
          tester,
          SectionCard(
            title: 'Skills',
            emphasis: emphasis,
            child: const Text('Content'),
          ),
        );

        expect(
          tester.getSemantics(find.text('Skills')),
          isSemantics(label: 'Skills', isHeader: true),
        );
      }
      handle.dispose();
    });
  });
}
