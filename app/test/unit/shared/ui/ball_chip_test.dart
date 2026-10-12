import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

Color _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(BallChip),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('shows the French letters, never the colour alone', (
    tester,
  ) async {
    for (final (kind, letter) in [
      (BallKind.red, 'R'),
      (BallKind.yellow, 'J'),
      (BallKind.black, 'N'),
      (BallKind.white, 'B'),
    ]) {
      await pumpUi(tester, BallChip(kind: kind), locale: const Locale('fr'));

      expect(find.text(letter), findsOneWidget, reason: '$kind');
    }
  });

  testWidgets('shows the English letters', (tester) async {
    for (final (kind, letter) in [
      (BallKind.red, 'R'),
      (BallKind.yellow, 'Y'),
      (BallKind.black, 'B'),
      (BallKind.white, 'W'),
    ]) {
      await pumpUi(tester, BallChip(kind: kind));

      expect(find.text(letter), findsOneWidget, reason: '$kind');
    }
  });

  testWidgets('exposes the ball name as a spoken label', (tester) async {
    await pumpUi(tester, const BallChip(kind: BallKind.yellow));

    expect(find.bySemanticsLabel('Yellow ball'), findsOneWidget);
  });

  testWidgets('uses the ball colours of the theme', (tester) async {
    await pumpUi(tester, const BallChip(kind: BallKind.red));
    expect(_fill(tester), BallColors.light.red);

    await pumpUi(tester, const BallChip(kind: BallKind.yellow));
    expect(_fill(tester), BallColors.light.yellow);

    await pumpUi(tester, const BallChip(kind: BallKind.black));
    expect(_fill(tester), BallColors.light.black);

    await pumpUi(tester, const BallChip(kind: BallKind.white));
    expect(_fill(tester), BallColors.light.white);
  });

  testWidgets('falls back to the default palette without the extension', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const BallChip(kind: BallKind.red),
      theme: ThemeData(),
    );

    expect(_fill(tester), BallColors.light.red);
  });

  testWidgets('honours the requested size', (tester) async {
    await pumpUi(tester, const BallChip(kind: BallKind.red, size: 64));

    expect(tester.getSize(find.byType(BallChip)), const Size(64, 64));
  });

  testWidgets('is 40 dp wide by default', (tester) async {
    await pumpUi(tester, const BallChip(kind: BallKind.red));

    expect(tester.getSize(find.byType(BallChip)), const Size(40, 40));
  });
}
