import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les boutons de la barre basse du guide, de gauche à droite puis de haut en
/// bas, avec leur libellé (texte, sinon infobulle) ; chacun doit faire au
/// moins 48 dp dans les deux sens.
List<String> guideBottomBarButtons(WidgetTester tester) {
  final bar = find.byKey(const ValueKey('guide-bottom-bar'));
  expect(bar, findsOneWidget, reason: 'barre basse du guide absente');
  final buttons = find
      .descendant(of: bar, matching: find.bySubtype<ButtonStyleButton>())
      .evaluate()
      .toList();
  final entries = <({double top, double left, String label})>[];
  for (final element in buttons) {
    final finder = find.byElementPredicate((e) => e == element);
    final rect = tester.getRect(finder);
    expect(rect.height, greaterThanOrEqualTo(47.5), reason: 'cible < 48 dp');
    expect(rect.width, greaterThanOrEqualTo(47.5), reason: 'cible < 48 dp');
    final texts = find
        .descendant(of: finder, matching: find.byType(Text))
        .evaluate();
    final tips = find
        .descendant(of: finder, matching: find.byType(Tooltip))
        .evaluate();
    final label = texts.isNotEmpty
        ? (texts.first.widget as Text).data
        : tips.isNotEmpty
        ? (tips.first.widget as Tooltip).message
        : null;
    entries.add((top: rect.center.dy, left: rect.left, label: label ?? '?'));
  }
  entries.sort((a, b) {
    final byRow = (a.top / 30).floor().compareTo((b.top / 30).floor());
    return byRow != 0 ? byRow : a.left.compareTo(b.left);
  });
  return [for (final entry in entries) entry.label];
}

/// Usage: the bottom bar offers {'Previous,Note the results,Next'}
///
/// Exactement ces boutons, dans cet ordre, tous d'au moins 48 dp.
Future<void> theBottomBarOffers(WidgetTester tester, String labels) async {
  expect(guideBottomBarButtons(tester), labels.split(','));
}
