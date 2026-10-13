import 'package:billard_cfa/shared/ui/cue_ball_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

/// Taille effective d'un `Text` : style hérité fusionné avec le sien.
double _effectiveSize(Element element) {
  final text = element.widget as Text;
  final merged = DefaultTextStyle.of(element).style.merge(text.style);
  return merged.fontSize ?? double.nan;
}

void main() {
  group('the geometry of the target (R = 100 px)', () {
    const geometry = CueBallTargetGeometry(
      center: Offset(200, 150),
      radius: 100,
    );

    test('has two rings, at half the radius and at the edge', () {
      expect(geometry.ringRadii, [50, 100]);
    });

    test('puts the tip of the centre hit on the centre', () {
      expect(geometry.markerCenter(TipPoint.center), const Offset(200, 150));
    });

    test('puts the tip at half a radius of the centre', () {
      expect(geometry.markerCenter(TipPoint.top), const Offset(200, 100));
      expect(geometry.markerCenter(TipPoint.bottom), const Offset(200, 200));
      expect(geometry.markerCenter(TipPoint.left), const Offset(150, 150));
      expect(geometry.markerCenter(TipPoint.right), const Offset(250, 150));
    });

    test('puts a diagonal at the same distance, 35.36 px on each axis', () {
      final p = geometry.markerCenter(TipPoint.topRight);

      expect(p.dx, closeTo(200 + 35.355, 0.01));
      expect(p.dy, closeTo(150 - 35.355, 0.01));
      expect((p - geometry.center).distance, closeTo(50, 1e-9));
    });

    test('draws the 8.5 mm tip at the scale of the 48.0 mm ball', () {
      // 8,5 / 48,0 x 100 px = 17,708 px (le rayon du procédé en rayons de
      // blanche : 4,25 / 24).
      expect(geometry.markerRadius, closeTo(17.708, 0.001));
      expect(geometry.markerEnlarged, isFalse);
    });
  });

  test('keeps a 10 px tip on a small ball, and says it is enlarged', () {
    const small = CueBallTargetGeometry(center: Offset.zero, radius: 40);

    expect(small.markerRadius, 10);
    expect(small.markerEnlarged, isTrue);
  });

  testWidgets('is spoken with the tip point in French', (tester) async {
    await pumpUi(
      tester,
      const CueBallTarget(tipPoint: TipPoint.top),
      locale: const Locale('fr'),
    );

    expect(
      find.bySemanticsLabel(
        'Cible sur la blanche vue de face : Procédé en haut de la blanche.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('is spoken in English with the profile and the comparison', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const CueBallTarget(
        tipPoint: TipPoint.bottom,
        cueHeight: CueHeight.high,
        compare: [TipPoint.center, TipPoint.top],
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Target on the cue ball seen from the front: Tip at the bottom of '
        'the cue ball. Cue seen from the side: High cue, butt raised. '
        'Points to compare: Tip at the centre of the cue ball, Tip at the '
        'top of the cue ball.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('names the four sides of the ball', (tester) async {
    await pumpUi(
      tester,
      const CueBallTarget(tipPoint: TipPoint.center),
      locale: const Locale('fr'),
    );

    for (final side in ['Haut', 'Bas', 'Gauche', 'Droite']) {
      expect(find.text(side), findsOneWidget);
    }
  });

  testWidgets('writes the tip point and the real sizes', (tester) async {
    await pumpUi(
      tester,
      const CueBallTarget(tipPoint: TipPoint.bottom),
      locale: const Locale('fr'),
    );

    expect(find.text('Procédé en bas de la blanche'), findsOneWidget);
    expect(
      find.text(
        "Le procédé (8,5 mm) est dessiné à l'échelle de la blanche (48,0 mm).",
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the side profile only when the cue height is given', (
    tester,
  ) async {
    await pumpUi(tester, const CueBallTarget(tipPoint: TipPoint.center));
    expect(find.byKey(const ValueKey('cue-ball-profile')), findsNothing);

    await pumpUi(
      tester,
      const CueBallTarget(
        tipPoint: TipPoint.center,
        cueHeight: CueHeight.level,
      ),
    );
    expect(find.byKey(const ValueKey('cue-ball-profile')), findsOneWidget);
    expect(find.text('Medium cue height'), findsOneWidget);
  });

  testWidgets('letters the points to compare', (tester) async {
    await pumpUi(
      tester,
      const CueBallTarget(
        tipPoint: TipPoint.center,
        compare: [TipPoint.top, TipPoint.bottom],
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsNothing);
  });

  testWidgets('writes every text at 14 or more, for a projection', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const CueBallTarget(
        tipPoint: TipPoint.topLeft,
        cueHeight: CueHeight.high,
        compare: [TipPoint.center],
      ),
    );

    final texts = tester.elementList(find.byType(Text)).toList();
    expect(texts, isNotEmpty);
    for (final element in texts) {
      expect(
        _effectiveSize(element),
        greaterThanOrEqualTo(14),
        reason: (element.widget as Text).data,
      );
    }
  });

  testWidgets('does not overflow on a narrow screen at 200 % text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpUi(
      tester,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: SingleChildScrollView(
          child: CueBallTarget(
            tipPoint: TipPoint.bottomRight,
            cueHeight: CueHeight.high,
            compare: [TipPoint.center, TipPoint.top],
          ),
        ),
      ),
      locale: const Locale('fr'),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('is drawn with the colours of the theme in the dark too', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const CueBallTarget(tipPoint: TipPoint.right),
      theme: ThemeData.dark(),
    );

    expect(tester.takeException(), isNull);
  });
}
