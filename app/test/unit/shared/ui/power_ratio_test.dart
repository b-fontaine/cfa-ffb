import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/ui/power_ratio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

const _longFast = PowerPoint(
  amplitude: AmplitudeLevel.long,
  speed: SpeedLevel.fast,
);
const _shortSlow = PowerPoint(
  amplitude: AmplitudeLevel.short,
  speed: SpeedLevel.slow,
  label: 'bille proche',
);

/// Taille effective d'un `Text` : style hérité fusionné avec le sien.
double _effectiveSize(Element element) {
  final text = element.widget as Text;
  final merged = DefaultTextStyle.of(element).style.merge(text.style);
  return merged.fontSize ?? double.nan;
}

void main() {
  group('the plane (400 x 300 px)', () {
    const plane = PowerPlaneGeometry(Size(400, 300));

    test('puts a long and fast stroke at the top right', () {
      expect(
        plane.positionOf(AmplitudeLevel.long, SpeedLevel.fast),
        const Offset(400, 0),
      );
    });

    test('puts a short and slow stroke at the bottom left', () {
      final p = plane.positionOf(AmplitudeLevel.short, SpeedLevel.slow);

      // 0,3 x 400 = 120 ; (1 - 0,3) x 300 = 210.
      expect(p.dx, closeTo(120, 1));
      expect(p.dy, closeTo(210, 1));
    });

    test('puts the zone limits on the product amplitude x speed', () {
      // À l'amplitude 0,5 : la limite « doux / moyen » (0,2) est à la
      // vitesse 0,4 ; la limite « moyen / puissant » (0,5) à la vitesse 1.
      expect(plane.speedAtLimit(powerSoftLimit, 0.5), closeTo(0.4, 1e-9));
      expect(plane.speedAtLimit(powerStrongLimit, 0.5), closeTo(1, 1e-9));
      expect(plane.speedAtLimit(powerStrongLimit, 0.25), isNull);
    });
  });

  testWidgets('names the three zones on the empty plane', (tester) async {
    await pumpUi(tester, const PowerRatio(), locale: const Locale('fr'));

    for (final zone in ['doux', 'moyen', 'puissant']) {
      expect(find.text(zone), findsOneWidget);
    }
    expect(
      find.bySemanticsLabel(
        'Plan amplitude et vitesse : trois zones, doux, moyen, puissant.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('power-point-0')), findsNothing);
  });

  testWidgets('writes the two axes with the direction of each', (tester) async {
    await pumpUi(tester, const PowerRatio(), locale: const Locale('fr'));

    expect(
      find.text('Amplitude, le recul de la main : de courte à longue'),
      findsOneWidget,
    );
    expect(
      find.text('Vitesse du coup de queue : de lente à rapide'),
      findsOneWidget,
    );
  });

  testWidgets('writes and speaks the zone reached by a point', (tester) async {
    await pumpUi(
      tester,
      const PowerRatio(points: [_longFast]),
      locale: const Locale('fr'),
    );

    expect(
      find.text('Amplitude longue, vitesse rapide : puissant'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Amplitude longue, vitesse rapide : puissant'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('power-point-0')), findsOneWidget);
  });

  testWidgets('speaks the English equivalent', (tester) async {
    await pumpUi(tester, const PowerRatio(points: [_longFast]));

    expect(
      find.bySemanticsLabel('Amplitude long, speed fast: strong'),
      findsOneWidget,
    );
  });

  testWidgets('numbers and labels two examples', (tester) async {
    await pumpUi(
      tester,
      const PowerRatio(points: [_shortSlow, _longFast]),
      locale: const Locale('fr'),
    );

    expect(
      find.text('1. bille proche : amplitude courte, vitesse lente : doux'),
      findsOneWidget,
    );
    expect(
      find.text('2. Amplitude longue, vitesse rapide : puissant'),
      findsOneWidget,
    );
  });

  testWidgets('marks only the highlighted example, with a check', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const PowerRatio(points: [_shortSlow, _longFast], highlight: 1),
    );

    expect(find.byKey(const ValueKey('power-highlight')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('power-point-1')),
        matching: find.byKey(const ValueKey('power-highlight')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('power-point-0')),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
  });

  testWidgets('marks nothing without a highlight', (tester) async {
    await pumpUi(tester, const PowerRatio(points: [_longFast]));

    expect(find.byKey(const ValueKey('power-highlight')), findsNothing);
  });

  testWidgets('writes the distance given by the session', (tester) async {
    await pumpUi(
      tester,
      const PowerRatio(points: [_longFast], distanceLabel: 'bille lointaine'),
    );

    expect(find.text('bille lointaine'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('Amplitude long, speed fast: strong.*bille lointaine'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('never writes a level number or the word "cran"', (tester) async {
    await pumpUi(
      tester,
      const PowerRatio(points: [_shortSlow, _longFast], highlight: 0),
      locale: const Locale('fr'),
    );

    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final data = (text.data ?? '').toLowerCase();

      expect(data, isNot(contains('cran')));
      expect(data, isNot(contains('niveau')));
    }
  });

  testWidgets('writes every text at 14 or more, for a projection', (
    tester,
  ) async {
    await pumpUi(tester, const PowerRatio(points: [_shortSlow, _longFast]));

    final texts = tester.elementList(find.byType(Text)).toList();
    expect(texts, isNotEmpty);
    for (final element in texts) {
      expect(_effectiveSize(element), greaterThanOrEqualTo(14));
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
          child: PowerRatio(
            points: [_shortSlow, _longFast],
            highlight: 1,
            distanceLabel: 'Jusqu’à la bande du fond et retour',
          ),
        ),
      ),
      locale: const Locale('fr'),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the three zone names 40 px away from any example', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpUi(tester, const PowerRatio());

    final plane = tester.getRect(
      find
          .descendant(
            of: find.byType(PowerRatio),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    // Marge de 18 px autour du plan (PowerRatio._padding).
    final inner = PowerPlaneGeometry(Size(plane.width - 36, plane.height - 36));
    final origin = plane.topLeft + const Offset(18, 18);
    for (final name in ['soft', 'medium', 'strong']) {
      final centre = tester.getCenter(find.text(name));
      for (final a in AmplitudeLevel.values) {
        for (final v in SpeedLevel.values) {
          final example = origin + inner.positionOf(a, v);

          expect(
            (centre - example).distance,
            greaterThanOrEqualTo(40),
            reason: '$name / $a / $v',
          );
        }
      }
    }
  });
}
