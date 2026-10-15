import 'dart:ui' show Tristate;

import 'package:billard_cfa/shared/ui/app_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

Widget _tabs({int selected = 0, ValueChanged<int>? onSelected}) => AppTabs(
  labels: const ['Planned', 'Catalogue', 'Suggestion'],
  selectedIndex: selected,
  onSelected: onSelected ?? (_) {},
);

void main() {
  testWidgets('shows every label', (tester) async {
    await pumpUi(tester, _tabs());

    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Catalogue'), findsOneWidget);
    expect(find.text('Suggestion'), findsOneWidget);
  });

  testWidgets('reports the tapped tab', (tester) async {
    int? tapped;
    await pumpUi(tester, _tabs(onSelected: (i) => tapped = i));

    await tester.tap(find.text('Suggestion'));

    expect(tapped, 2);
  });

  testWidgets('marks only the selected tab as selected for accessibility', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, _tabs(selected: 1));

    final selected = tester.getSemantics(find.text('Catalogue'));
    final other = tester.getSemantics(find.text('Planned'));

    expect(selected.label, 'Catalogue');
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
    expect(selected.flagsCollection.isButton, isTrue);
    expect(other.flagsCollection.isSelected, isNot(Tristate.isTrue));
    expect(other.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('every tab is at least 48 dp high', (tester) async {
    await pumpUi(tester, _tabs());

    for (final label in ['Planned', 'Catalogue', 'Suggestion']) {
      final box = tester.getRect(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      );
      expect(box.height, greaterThanOrEqualTo(48));
    }
  });
}
