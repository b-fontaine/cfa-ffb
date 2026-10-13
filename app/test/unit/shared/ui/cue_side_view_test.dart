import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:billard_cfa/shared/ui/cue_side_view.dart';
import 'package:billard_cfa/shared/ui/tip_point.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('is spoken with the height and the tip point in French', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const CueSideView(tipPoint: TipPoint.top, cueHeight: CueHeight.high),
      locale: const Locale('fr'),
    );

    expect(
      find.bySemanticsLabel(
        'Vue de côté : Queue haute, talon relevé. '
        'Procédé en haut de la blanche.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('adds the bridge to the speech and writes it', (tester) async {
    await pumpUi(
      tester,
      const CueSideView(
        tipPoint: TipPoint.center,
        cueHeight: CueHeight.level,
        bridge: CueBridge.frame,
      ),
      locale: const Locale('fr'),
    );

    expect(
      find.bySemanticsLabel(
        'Vue de côté : Queue à hauteur moyenne. '
        'Procédé au centre de la blanche. Chevalet sur cadre.',
      ),
      findsOneWidget,
    );
    expect(find.text('Chevalet sur cadre'), findsOneWidget);
    expect(find.text('Queue à hauteur moyenne'), findsOneWidget);
  });

  testWidgets('writes the English names of both bridges', (tester) async {
    for (final entry in {
      CueBridge.frame: 'Rail bridge',
      CueBridge.surface: 'Table bridge',
    }.entries) {
      await pumpUi(
        tester,
        CueSideView(
          tipPoint: TipPoint.bottom,
          cueHeight: CueHeight.low,
          bridge: entry.key,
        ),
      );

      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('shows no bridge text when the bridge is unknown', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const CueSideView(tipPoint: TipPoint.center, cueHeight: CueHeight.low),
    );

    expect(find.text('Rail bridge'), findsNothing);
    expect(find.text('Table bridge'), findsNothing);
  });

  testWidgets('tilts the cue by the elevation of its height', (tester) async {
    for (final entry in {
      CueHeight.low: 0.0,
      CueHeight.level: 10 * math.pi / 180,
      CueHeight.high: 25 * math.pi / 180,
    }.entries) {
      await pumpUi(
        tester,
        CueSideView(tipPoint: TipPoint.center, cueHeight: entry.key),
      );

      expect(
        tester.widget<BilliardCue>(find.byType(BilliardCue)).angle,
        closeTo(entry.value, 1e-12),
        reason: '${entry.key}',
      );
    }
  });

  testWidgets('places the cue tip higher for a top hit than a bottom hit', (
    tester,
  ) async {
    Future<double> cueCentreY(TipPoint tip) async {
      await pumpUi(
        tester,
        CueSideView(tipPoint: tip, cueHeight: CueHeight.low),
      );
      return tester.getCenter(find.byType(BilliardCue)).dy;
    }

    final top = await cueCentreY(TipPoint.top);
    final centre = await cueCentreY(TipPoint.center);
    final bottom = await cueCentreY(TipPoint.bottom);

    expect(top, lessThan(centre));
    expect(centre, lessThan(bottom));
  });

  testWidgets('draws a single ball and does not overflow when narrow', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const Center(
        child: SizedBox(
          width: 150,
          child: CueSideView(
            tipPoint: TipPoint.bottomLeft,
            cueHeight: CueHeight.high,
            bridge: CueBridge.surface,
          ),
        ),
      ),
    );

    expect(find.byType(BilliardBall), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('contact with an object ball', () {
    const view = CueSideView(
      tipPoint: TipPoint.center,
      cueHeight: CueHeight.level,
      showContact: true,
    );

    testWidgets('draws no object ball unless the contact is asked', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const CueSideView(tipPoint: TipPoint.center, cueHeight: CueHeight.low),
      );

      expect(find.byType(BilliardBall), findsOneWidget);
    });

    testWidgets('draws a bigger object ball beside the cue ball', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const Center(child: SizedBox(width: 480, child: view)),
      );

      final balls = find.byType(BilliardBall);
      expect(balls, findsNWidgets(2));
      final cue = tester.widget<BilliardBall>(balls.first);
      final object = tester.widget<BilliardBall>(balls.last);
      expect(cue.kind, BallKind.white);
      expect(object.kind, BallKind.red);
      // Écart de taille exagéré x10 : rayon 24,0 + 10 x 1,4 = 38,0 mm.
      final white = tester.getSize(balls.first).width;
      final red = tester.getSize(balls.last).width;
      expect(white / red, closeTo(24.0 / 38.0, 1e-6));
    });

    testWidgets('the balls touch: centre distance is r_c + r_o', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const Center(child: SizedBox(width: 480, child: view)),
      );

      final balls = find.byType(BilliardBall);
      final white = tester.getSize(balls.first).width / 2;
      final red = tester.getSize(balls.last).width / 2;
      final distance =
          (tester.getCenter(balls.last) - tester.getCenter(balls.first))
              .distance;
      expect(distance, closeTo(white + red, 1e-6));
    });

    testWidgets('both balls rest on the same cloth line', (tester) async {
      await pumpUi(
        tester,
        const Center(child: SizedBox(width: 480, child: view)),
      );

      final balls = find.byType(BilliardBall);
      final whiteBottom = tester.getRect(balls.first).bottom;
      final redBottom = tester.getRect(balls.last).bottom;
      expect(whiteBottom, closeTo(redBottom, 1e-6));
      // Le centre de la bille de but est plus haut que celui de la blanche.
      expect(
        tester.getCenter(balls.last).dy,
        lessThan(tester.getCenter(balls.first).dy),
      );
    });

    testWidgets('marks the contact above the cue ball equator', (tester) async {
      await pumpUi(
        tester,
        const Center(child: SizedBox(width: 480, child: view)),
      );

      final balls = find.byType(BilliardBall);
      final white = tester.getCenter(balls.first);
      final radius = tester.getSize(balls.first).width / 2;
      // sin phi = 14 / 62 : le contact est à 24,0 x 14 / 62 = 5,419 mm, soit
      // 0,2258 rayon de blanche, au-dessus de l'équateur.
      final marker = find.byKey(const ValueKey('cue-side-contact'));
      expect(marker, findsOneWidget);
      final contact = tester.getCenter(marker);
      expect(white.dy - contact.dy, closeTo(radius * 14 / 62, 1e-6));
      expect(
        contact.dx - white.dx,
        closeTo(radius * math.sqrt(1 - math.pow(14 / 62, 2)), 1e-6),
      );
    });

    testWidgets('says that the gap is exaggerated, in both languages', (
      tester,
    ) async {
      await pumpUi(tester, view, locale: const Locale('fr'));
      expect(find.textContaining('exagérés ×10'), findsOneWidget);
      expect(find.textContaining('48,0 mm'), findsOneWidget);
      expect(find.textContaining('50,8 mm'), findsOneWidget);

      await pumpUi(tester, view);
      expect(find.textContaining('exaggerated ×10'), findsOneWidget);
      expect(find.textContaining('48.0 mm'), findsOneWidget);
    });

    testWidgets('speaks the exaggeration too', (tester) async {
      await pumpUi(tester, view, locale: const Locale('fr'));

      expect(
        find.bySemanticsLabel(RegExp('^Vue de côté : .*exagérés ×10')),
        findsOneWidget,
      );
    });

    testWidgets('paints the equator above the balls, not under them', (
      tester,
    ) async {
      await pumpUi(
        tester,
        const SizedBox(
          width: 480,
          child: CueSideView(
            tipPoint: TipPoint.center,
            cueHeight: CueHeight.level,
            showContact: true,
          ),
        ),
      );

      final stack = tester.widget<Stack>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('cue-side-equator')),
              matching: find.byType(Stack),
            )
            .first,
      );
      int indexOf(bool Function(Widget) test) =>
          stack.children.indexWhere(test);
      final equator = indexOf(
        (w) => w is Positioned && w.child is IgnorePointer,
      );
      final lastBall = stack.children.lastIndexWhere(
        (w) => w is Positioned && w.child is BilliardBall,
      );

      expect(equator, greaterThan(lastBall));
    });
  });
}
