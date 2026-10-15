import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/power_ratio.dart';
import 'package:billard_cfa/shared/ui/angle_mark.dart';
import 'package:billard_cfa/shared/ui/ball_size_comparison.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/contact_height_view.dart';
import 'package:billard_cfa/shared/ui/contact_strip.dart';
import 'package:billard_cfa/shared/ui/cue_ball_target.dart';
import 'package:billard_cfa/shared/ui/player_figure.dart';
import 'package:billard_cfa/shared/ui/power_ratio.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

// Les quatre figures introduites par le retour « blanche plus petite,
// personnage, cible, amplitude / vitesse » : mode présentation, texte à 200 %,
// thème sombre, lisibilité (texte >= 14, contrastes >= 3:1).

const _fr = Locale('fr');
const _points = [
  PowerPoint(amplitude: AmplitudeLevel.short, speed: SpeedLevel.slow),
  PowerPoint(amplitude: AmplitudeLevel.long, speed: SpeedLevel.fast),
];

/// Les quatre figures et un texte qu'elles écrivent toujours en français.
final Map<String, ({Widget Function() build, Finder anchor})> _figures = {
  'CueBallTarget': (
    build: () => const CueBallTarget(tipPoint: TipPoint.top),
    anchor: find.text('Haut'),
  ),
  'PlayerFigure': (
    build: () => const PlayerFigure(view: PlayerView.both),
    anchor: find.byKey(const ValueKey('player-legend-1')),
  ),
  'PowerRatio': (
    build: () => const PowerRatio(points: _points, highlight: 1),
    anchor: find.text('doux'),
  ),
  'BallSizeComparison': (
    build: () => const BallSizeComparison(),
    anchor: find.text('48,0 mm'),
  ),
  'ContactHeightView': (
    build: () => const ContactHeightView(),
    anchor: find.text('Point de contact'),
  ),
};

Future<void> _surface(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pump();
}

/// Les `CustomPainter` peints sous [type].
List<CustomPainter> _painters(WidgetTester tester, Type type) => [
  for (final paint in tester.widgetList<CustomPaint>(
    find.descendant(of: find.byType(type), matching: find.byType(CustomPaint)),
  ))
    if (paint.painter != null) paint.painter!,
];

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Tailles effectives (px, texte à 1) de tous les textes sous [type].
List<double> _fontSizes(WidgetTester tester, Type type) => [
  for (final element
      in find
          .descendant(of: find.byType(type), matching: find.byType(RichText))
          .evaluate())
    (tester
            .renderObject<RenderParagraph>(
              find.byElementPredicate((e) => e == element),
            )
            .text
            .style
            ?.fontSize ??
        double.nan),
];

void main() {
  for (final entry in _figures.entries) {
    group(entry.key, () {
      testWidgets('is wider in the presentation than outside it', (
        tester,
      ) async {
        await _surface(tester, 1400, 900);
        await pumpUi(
          tester,
          SingleChildScrollView(child: entry.value.build()),
          locale: _fr,
        );
        final plain = tester.getSize(
          find.byType(entry.value.build().runtimeType),
        );

        await pumpUi(
          tester,
          SingleChildScrollView(
            child: PresentationScope(child: entry.value.build()),
          ),
          locale: _fr,
        );

        expect(tester.takeException(), isNull);
        expect(entry.value.anchor, findsWidgets);
        final shown = tester.getSize(
          find.byType(entry.value.build().runtimeType),
        );
        expect(shown.height, greaterThanOrEqualTo(plain.height));
      });

      testWidgets('survives the presentation on a phone at 200 % text', (
        tester,
      ) async {
        await _surface(tester, 320, 640);
        await pumpUi(
          tester,
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(
              child: PresentationScope(child: entry.value.build()),
            ),
          ),
          locale: _fr,
        );

        expect(tester.takeException(), isNull);
        expect(entry.value.anchor, findsWidgets);
      });

      testWidgets('writes every text at 14 px or more', (tester) async {
        await _surface(tester, 800, 1600);
        await pumpUi(
          tester,
          SingleChildScrollView(child: entry.value.build()),
          locale: _fr,
        );

        final sizes = _fontSizes(tester, entry.value.build().runtimeType);
        expect(sizes, isNotEmpty);
        for (final size in sizes) {
          expect(size, greaterThanOrEqualTo(14));
        }
      });

      testWidgets('is drawn with other inks in the dark theme', (tester) async {
        await _surface(tester, 800, 1600);
        final type = entry.value.build().runtimeType;
        await pumpUi(
          tester,
          SingleChildScrollView(child: entry.value.build()),
          locale: _fr,
          theme: AppTheme.light(),
        );
        final light = _painters(tester, type);
        await pumpUi(
          tester,
          SingleChildScrollView(child: entry.value.build()),
          locale: _fr,
          theme: AppTheme.dark(),
        );
        await tester.pumpAndSettle();
        final dark = _painters(tester, type);

        expect(tester.takeException(), isNull);
        if (entry.key == 'BallSizeComparison') {
          // Pas de peintre propre : les billes portent leurs couleurs.
          expect(find.byType(BilliardBall), findsNWidgets(2));
          return;
        }
        expect(dark, isNotEmpty);
        expect(dark.length, light.length);
        for (var i = 0; i < dark.length; i++) {
          expect(dark[i].shouldRepaint(light[i]), isTrue, reason: 'painter $i');
        }
      });
    });
  }

  group('contrast of the inks used by the figures (>= 3:1)', () {
    for (final (name, theme) in [
      ('light', AppTheme.light()),
      ('dark', AppTheme.dark()),
    ]) {
      test('$name theme: silhouette, body and leader against the plate', () {
        final scheme = theme.colorScheme;
        final plate = scheme.surfaceContainerHighest;

        expect(_contrast(scheme.onSurface, plate), greaterThanOrEqualTo(3));
        expect(_contrast(scheme.primary, plate), greaterThanOrEqualTo(3));
        expect(
          _contrast(scheme.onSurfaceVariant, plate),
          greaterThanOrEqualTo(3),
        );
        expect(
          _contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(3),
        );
        expect(
          _contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(3),
        );
      });
    }
  });

  group('BallSizeComparison', () {
    testWidgets('keeps the cue ball smaller by at least 1 px when tiny', (
      tester,
    ) async {
      await pumpUi(tester, const BallSizeComparison(objectDiameter: 40));

      final balls = tester
          .widgetList<BilliardBall>(find.byType(BilliardBall))
          .toList();
      final white = balls.firstWhere((b) => b.kind.name == 'white');
      final red = balls.firstWhere((b) => b.kind.name != 'white');

      // 40 x 24,0 / 25,4 = 37,795 : écart de 2,2 px.
      expect(white.diameter, closeTo(37.795, 1e-3));
      expect(red.diameter! - white.diameter!, greaterThanOrEqualTo(1));
    });

    testWidgets('fits 320 px wide at 200 % text', (tester) async {
      await _surface(tester, 320, 640);
      await pumpUi(
        tester,
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SingleChildScrollView(child: BallSizeComparison()),
        ),
        locale: _fr,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the balls apart from the plate in the dark theme', (
      tester,
    ) async {
      await pumpUi(tester, const BallSizeComparison(), theme: AppTheme.dark());

      expect(tester.takeException(), isNull);
      expect(find.text('48.0 mm'), findsOneWidget);
    });
  });

  group('previously uncovered branches', () {
    testWidgets('PowerRatio repaints on points or scheme only', (tester) async {
      Future<CustomPainter> painter(
        List<PowerPoint> points,
        ThemeData theme,
      ) async {
        await pumpUi(tester, PowerRatio(points: points), theme: theme);
        await tester.pumpAndSettle();
        return _painters(tester, PowerRatio).first;
      }

      final base = await painter(_points, AppTheme.light());
      final same = await painter(_points, AppTheme.light());
      final fewer = await painter([_points.first], AppTheme.light());
      final dark = await painter(_points, AppTheme.dark());

      expect(same.shouldRepaint(base), isFalse);
      expect(fewer.shouldRepaint(base), isTrue);
      expect(dark.shouldRepaint(base), isTrue);
    });

    testWidgets('ContactStrip takes a fixed width in an unbounded row', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ContactStrip(
            fractions: [ContactFraction.full, ContactFraction.half],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ContactStrip)).width, greaterThan(300));
    });

    testWidgets('AngleMark repaints when the kind or the rays change', (
      tester,
    ) async {
      const rays5 = [math.Point<double>(5, 3), math.Point<double>(4, 2)];
      const rays6 = [math.Point<double>(6, 3), math.Point<double>(4, 2)];
      Future<CustomPainter> painter(
        AngleKind kind,
        List<math.Point<double>> rays,
      ) async {
        await pumpUi(
          tester,
          AngleMark(kind: kind, vertex: const math.Point(4, 4), rays: rays),
        );
        return tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((c) => c.painter)
            .whereType<CustomPainter>()
            .firstWhere((p) => p.runtimeType.toString() == '_AnglePainter');
      }

      final base = await painter(AngleKind.bounce, rays5);

      expect(
        (await painter(AngleKind.bounce, rays5)).shouldRepaint(base),
        isFalse,
      );
      expect(
        (await painter(AngleKind.rightAngle, rays5)).shouldRepaint(base),
        isTrue,
      );
      expect(
        (await painter(AngleKind.bounce, rays6)).shouldRepaint(base),
        isTrue,
      );
    });
  });
}
