import 'dart:math' as math;

import 'package:billard_cfa/shared/ui/billiard_cue.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('occupies a length by thickness box', (tester) async {
    await pumpUi(
      tester,
      const Center(child: BilliardCue(length: 240, thickness: 12)),
    );

    expect(tester.getSize(find.byType(BilliardCue)), const Size(240, 12));
  });

  testWidgets('is spoken with a localised name', (tester) async {
    await pumpUi(tester, const BilliardCue());
    expect(find.bySemanticsLabel('Billiard cue'), findsOneWidget);

    await pumpUi(tester, const BilliardCue(), locale: const Locale('fr'));
    expect(find.bySemanticsLabel('Queue de billard'), findsOneWidget);
  });

  testWidgets('rotates by the requested angle around the tip', (tester) async {
    await pumpUi(tester, const Center(child: BilliardCue(angle: math.pi / 2)));

    final transform = tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(BilliardCue),
            matching: find.byType(Transform),
          ),
        )
        .transform;
    expect(transform.entry(0, 0), closeTo(math.cos(math.pi / 2), 1e-9));
    expect(transform.entry(1, 0), closeTo(1, 1e-9));
    // The layout box (hence the tip at its right-hand middle) is unmoved.
    expect(tester.getSize(find.byType(BilliardCue)), const Size(200, 10));
  });

  testWidgets('paints its four parts', (tester) async {
    await pumpUi(tester, const Center(child: BilliardCue()));

    final paint = tester.renderObject(
      find
          .descendant(
            of: find.byType(BilliardCue),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(
      paint,
      paints
        ..path()
        ..path()
        ..path()
        ..path()
        ..path()
        ..path()
        ..path()
        ..path()
        ..path(),
    );
  });

  group('positionedAgainst', () {
    const geometry = TableGeometry(surface: Rect.fromLTWH(40, 30, 400, 200));

    for (final angle in [0.0, math.pi / 2, math.pi / 4, math.pi]) {
      testWidgets('puts the tip against the ball at angle $angle', (
        tester,
      ) async {
        const ball = Offset(5, 2);
        await pumpUi(
          tester,
          SizedBox(
            width: 600,
            height: 400,
            child: Stack(
              children: [
                BilliardCue.positionedAgainst(
                  geometry: geometry,
                  ball: ball,
                  angle: angle,
                ),
              ],
            ),
          ),
        );

        final tip = tester.getRect(find.byType(BilliardCue)).centerRight;
        final centre = geometry.toPixel(ball);
        expect((tip - centre).distance, closeTo(geometry.ballRadiusPx, 0.01));
        final direction = Offset(math.cos(angle), math.sin(angle));
        final expected = centre - direction * geometry.ballRadiusPx;
        final stack = tester.getTopLeft(find.byType(Stack).first);
        expect(tip - stack, offsetMoreOrLessEquals(expected, epsilon: 0.01));
      });
    }

    testWidgets('has a length given in cells', (tester) async {
      await pumpUi(
        tester,
        Stack(
          children: [
            BilliardCue.positionedAgainst(
              geometry: geometry,
              ball: const Offset(5, 2),
              lengthCells: 4,
            ),
          ],
        ),
      );

      expect(tester.getSize(find.byType(BilliardCue)).width, 4 * 50);
    });
  });

  group('pivot on the tip', () {
    for (final angle in [
      0.0,
      math.pi / 4,
      math.pi / 2,
      -math.pi / 4,
      math.pi,
    ]) {
      testWidgets('the tip stays at the right-hand middle for $angle', (
        tester,
      ) async {
        await pumpUi(
          tester,
          Center(child: BilliardCue(length: 240, thickness: 12, angle: angle)),
        );

        final box = tester.getRect(find.byType(BilliardCue));
        final rotated = tester.renderObject<RenderTransform>(
          find.descendant(
            of: find.byType(BilliardCue),
            matching: find.byType(Transform),
          ),
        );
        final tip = rotated.localToGlobal(const Offset(240, 6));
        expect(tip, offsetMoreOrLessEquals(box.centerRight, epsilon: 0.01));
      });
    }
  });

  group('painted parts', () {
    testWidgets('tip, ferrule, shaft, butt and ring in the theme colours', (
      tester,
    ) async {
      await pumpUi(tester, const Center(child: BilliardCue()));
      final painter = tester
          .widget<CustomPaint>(
            find
                .descendant(
                  of: find.byType(BilliardCue),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .painter!;
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(200, 10));

      final paints = [
        for (final call in canvas.invocations)
          if (call.invocation.memberName == #drawPath)
            call.invocation.positionalArguments[1] as Paint,
      ];
      expect(paints, hasLength(9));
      final fills = [
        for (final p in paints)
          if (p.style == PaintingStyle.fill) p.color.toARGB32(),
      ];
      const table = TableColors.light;
      expect(fills, [
        table.cueTip.toARGB32(),
        table.cueFerrule.toARGB32(),
        table.cueWood.toARGB32(),
        table.cueButt.toARGB32(),
        table.cueFerrule.toARGB32(),
      ]);
      final outlines = paints.where((p) => p.style == PaintingStyle.stroke);
      expect(outlines, hasLength(4));
      for (final outline in outlines) {
        expect(outline.color.toARGB32(), table.cueButt.toARGB32());
      }
    });

    testWidgets('uses the dark palette in the dark theme', (tester) async {
      await pumpUi(
        tester,
        const Center(child: BilliardCue()),
        theme: AppTheme.dark(),
      );
      final painter = tester
          .widget<CustomPaint>(
            find
                .descendant(
                  of: find.byType(BilliardCue),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .painter!;
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, const Size(200, 10));
      final first = canvas.invocations
          .map((c) => c.invocation)
          .firstWhere((c) => c.memberName == #drawPath);
      expect(
        (first.positionalArguments[1] as Paint).color.toARGB32(),
        TableColors.dark.cueTip.toARGB32(),
      );
    });
  });

  group('positionedAgainst thickness', () {
    Future<double> thicknessFor(
      WidgetTester tester,
      double surfaceWidth,
    ) async {
      final geometry = TableGeometry(
        surface: Rect.fromLTWH(0, 0, surfaceWidth, surfaceWidth / 2),
      );
      await pumpUi(
        tester,
        Stack(
          children: [
            BilliardCue.positionedAgainst(
              geometry: geometry,
              ball: const Offset(5, 2),
            ),
          ],
        ),
      );
      return tester.getSize(find.byType(BilliardCue)).height;
    }

    testWidgets('has a floor of 7 px on a small table (unit 20)', (
      tester,
    ) async {
      expect(await thicknessFor(tester, 160), 7);
    });

    testWidgets('follows 20 % of a case on a large table (unit 50)', (
      tester,
    ) async {
      expect(await thicknessFor(tester, 400), closeTo(10, 1e-9));
    });

    testWidgets('switches at unit 35 (7 px both ways)', (tester) async {
      expect(await thicknessFor(tester, 280), closeTo(7, 1e-9));
    });
  });
}
