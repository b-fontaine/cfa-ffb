import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/ball_size_comparison.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

Finder _ball(BallKind kind) => find.byWidgetPredicate(
  (w) => w is BilliardBall && w.kind == kind,
  description: 'ball $kind',
);

void main() {
  testWidgets('draws the cue ball 24.0 / 25.4 of the object ball', (
    tester,
  ) async {
    await pumpUi(tester, const BallSizeComparison(objectDiameter: 127));

    // 127 px pour 50,8 mm : 2,5 px par mm ; blanche 48,0 mm = 120 px.
    expect(tester.getSize(_ball(BallKind.red)).width, closeTo(127, 1e-9));
    expect(tester.getSize(_ball(BallKind.white)).width, closeTo(120, 1e-9));
  });

  testWidgets('puts both balls on the same line', (tester) async {
    await pumpUi(tester, const BallSizeComparison());

    expect(
      tester.getRect(_ball(BallKind.white)).bottom,
      closeTo(tester.getRect(_ball(BallKind.red)).bottom, 1e-9),
    );
  });

  testWidgets('writes both diameters, in English', (tester) async {
    await pumpUi(tester, const BallSizeComparison());

    expect(find.text('48.0 mm'), findsOneWidget);
    expect(find.text('50.8 mm'), findsOneWidget);
    expect(find.text('White ball'), findsOneWidget);
  });

  testWidgets('writes both diameters with a decimal comma in French', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const BallSizeComparison(),
      locale: const Locale('fr'),
    );

    expect(find.text('48,0 mm'), findsOneWidget);
    expect(find.text('50,8 mm'), findsOneWidget);
    expect(
      find.text(
        'La blanche est un peu plus petite et plus légère que les billes de '
        'but.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('is spoken as one description', (tester) async {
    await pumpUi(
      tester,
      const BallSizeComparison(),
      locale: const Locale('fr'),
    );

    expect(
      find.bySemanticsLabel(
        'Comparaison de taille : la blanche mesure 48,0 mm, une bille de but '
        '50,8 mm.',
      ),
      findsOneWidget,
    );
  });
}
