import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/illustration.dart';
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
}
