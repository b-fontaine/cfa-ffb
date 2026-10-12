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
}
