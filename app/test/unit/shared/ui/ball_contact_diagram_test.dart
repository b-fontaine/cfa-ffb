import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

/// Vrai si une peinture contient un cercle centré en [center] de rayon
/// [radius] (et de couleur [color] s'il est précisé).
PaintPattern _circle(Offset center, double radius, {Color? color}) =>
    paints..something((method, arguments) {
      if (method != #drawCircle) return false;
      final at = arguments[0] as Offset;
      final r = arguments[1] as double;
      final paint = arguments[2] as Paint;
      return (at - center).distance < 1e-6 &&
          (r - radius).abs() < 1e-6 &&
          (color == null || paint.color.toARGB32() == color.toARGB32());
    });

void main() {
  group('ContactFraction', () {
    test('overlap decreases from the full ball to the thin cut', () {
      expect(ContactFraction.values.map((c) => c.overlap), [
        1,
        0.75,
        0.5,
        0.25,
        0.05,
      ]);
    });

    test('centres are offset by two radii times the missing overlap', () {
      expect(ContactFraction.full.centerOffset, 0);
      expect(ContactFraction.threeQuarter.centerOffset, 0.5);
      expect(ContactFraction.half.centerOffset, 1);
      expect(ContactFraction.quarter.centerOffset, 1.5);
      expect(ContactFraction.thin.centerOffset, closeTo(1.9, 1e-9));
    });
  });

  group('TipPoint', () {
    test('the centre has no offset and the sides point outwards', () {
      expect(TipPoint.center.direction, Offset.zero);
      expect(TipPoint.top.direction, const Offset(0, -1));
      expect(TipPoint.bottom.direction, const Offset(0, 1));
      expect(TipPoint.left.direction, const Offset(-1, 0));
      expect(TipPoint.right.direction, const Offset(1, 0));
    });
  });

  testWidgets('writes the localised fraction under the diagram', (
    tester,
  ) async {
    final expected = {
      ContactFraction.full: 'Bille pleine',
      ContactFraction.threeQuarter: 'Trois-quarts de bille',
      ContactFraction.half: 'Demi-bille',
      ContactFraction.quarter: 'Quart de bille',
      ContactFraction.thin: 'Finesse',
    };
    for (final entry in expected.entries) {
      await pumpUi(
        tester,
        BallContactDiagram(contact: entry.key),
        locale: const Locale('fr'),
      );

      expect(find.text(entry.value), findsOneWidget, reason: '${entry.key}');
    }
  });

  testWidgets('writes the English fraction', (tester) async {
    await pumpUi(
      tester,
      const BallContactDiagram(contact: ContactFraction.half),
    );

    expect(find.text('Half ball'), findsOneWidget);
  });

  testWidgets('is spoken with the fraction and the tip point', (tester) async {
    await pumpUi(
      tester,
      const BallContactDiagram(
        contact: ContactFraction.quarter,
        tipPoint: TipPoint.top,
      ),
      locale: const Locale('fr'),
    );

    expect(
      find.bySemanticsLabel('Quart de bille ; Procédé en haut de la blanche'),
      findsOneWidget,
    );
  });

  testWidgets('paints the two balls, the front view and the blue dot', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const BallContactDiagram(
        contact: ContactFraction.half,
        tipPoint: TipPoint.right,
        target: BallKind.yellow,
      ),
    );

    final paint = tester.renderObject(
      find
          .descendant(
            of: find.byType(BallContactDiagram),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(
      paint,
      paints
        ..rrect()
        ..line()
        ..circle(),
    );
  });

  testWidgets('keeps a 2:1 drawing area', (tester) async {
    await pumpUi(
      tester,
      const Center(
        child: SizedBox(
          width: 300,
          child: BallContactDiagram(contact: ContactFraction.full),
        ),
      ),
    );

    final area = tester.getSize(
      find
          .descendant(
            of: find.byType(BallContactDiagram),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(area.width / area.height, closeTo(2, 1e-9));
  });

  group('text scale', () {
    for (final scale in [1.5, 2.0]) {
      testWidgets('keeps the label and the drawing at x$scale', (tester) async {
        await pumpUi(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: const Center(
                child: SizedBox(
                  width: 200,
                  child: BallContactDiagram(
                    contact: ContactFraction.threeQuarter,
                  ),
                ),
              ),
            ),
          ),
          locale: const Locale('fr'),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Trois-quarts de bille'), findsOneWidget);
        final area = tester.getSize(
          find
              .descendant(
                of: find.byType(BallContactDiagram),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        expect(area, const Size(200, 100));
      });
    }
  });

  group('repaint', () {
    // Le schéma est un simple `CustomPaint` : on compare le peintre d'avant et
    // celui d'après un changement d'un seul champ.
    Future<CustomPainter> painter(
      WidgetTester tester, {
      ContactFraction contact = ContactFraction.half,
      TipPoint tip = TipPoint.center,
      BallKind target = BallKind.red,
      ThemeData? theme,
    }) async {
      await pumpUi(
        tester,
        BallContactDiagram(contact: contact, tipPoint: tip, target: target),
        theme: theme,
      );
      await tester.pumpAndSettle();
      return tester
          .widget<CustomPaint>(
            find
                .descendant(
                  of: find.byType(BallContactDiagram),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .painter!;
    }

    testWidgets('repaints only when a field of the drawing changes', (
      tester,
    ) async {
      final before = await painter(tester);

      final same = await painter(tester);
      expect(same.shouldRepaint(before), isFalse);

      final contact = await painter(tester, contact: ContactFraction.quarter);
      expect(contact.shouldRepaint(before), isTrue);

      final tip = await painter(tester, tip: TipPoint.top);
      expect(tip.shouldRepaint(before), isTrue);

      final target = await painter(tester, target: BallKind.yellow);
      expect(target.shouldRepaint(before), isTrue);

      final dark = await painter(tester, theme: AppTheme.dark());
      expect(dark.shouldRepaint(before), isTrue);
    });
  });

  group('geometry of the drawing', () {
    // Zone de dessin de 400 x 200 : h = 200, rayon des billes = 0,2 h = 40,
    // blanche en (90 ; 128). Valeurs calculées à la main.
    const width = 400.0;
    const radius = 40.0;
    const cue = Offset(90, 128);

    Future<RenderObject> area(
      WidgetTester tester, {
      required ContactFraction contact,
      TipPoint tip = TipPoint.center,
      BallKind target = BallKind.red,
      ThemeData? theme,
      Key? boundary,
    }) async {
      await pumpUi(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: RepaintBoundary(
              key: boundary,
              child: BallContactDiagram(
                contact: contact,
                tipPoint: tip,
                target: target,
              ),
            ),
          ),
        ),
        theme: theme,
      );
      // Le changement de thème est animé : attendre la valeur finale.
      await tester.pumpAndSettle();
      return tester.renderObject(
        find
            .descendant(
              of: find.byType(BallContactDiagram),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
    }

    testWidgets('full ball: the target sits on the line of aim', (
      tester,
    ) async {
      final paint = await area(tester, contact: ContactFraction.full);
      // Centres à 2 rayons, sur la même ligne horizontale.
      expect(paint, _circle(const Offset(90, 128), radius));
      expect(paint, _circle(const Offset(170, 128), radius));
    });

    testWidgets('half ball: centres 2r apart, shifted by one radius', (
      tester,
    ) async {
      final paint = await area(tester, contact: ContactFraction.half);
      final dx = math.sqrt(3) * radius;
      expect(paint, _circle(const Offset(90, 128), radius));
      expect(paint, _circle(Offset(cue.dx + dx, cue.dy - radius), radius));
    });

    testWidgets('quarter ball: shifted by one and a half radius', (
      tester,
    ) async {
      final paint = await area(tester, contact: ContactFraction.quarter);
      final dx = math.sqrt(4 - 2.25) * radius;
      expect(
        paint,
        _circle(Offset(cue.dx + dx, cue.dy - 1.5 * radius), radius),
      );
    });

    testWidgets('the front ball is a ball of radius 0.28 h at (1.5 h ; h/2)', (
      tester,
    ) async {
      final paint = await area(tester, contact: ContactFraction.full);
      expect(paint, _circle(const Offset(300, 100), 56));
    });

    for (final tip in TipPoint.values) {
      testWidgets('tip point ${tip.name}: blue dot at 0.55 radius', (
        tester,
      ) async {
        final paint = await area(
          tester,
          contact: ContactFraction.full,
          tip: tip,
        );
        const front = Offset(300, 100);
        const frontRadius = 56.0;
        final expected = front + tip.direction * (0.55 * frontRadius);
        expect(
          paint,
          _circle(expected, 0.17 * frontRadius, color: TableColors.light.chalk),
        );
      });
    }

    Future<Color> pixelAt(
      WidgetTester tester,
      GlobalKey key,
      Offset point,
    ) async {
      late Color pixel;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = (await image.toByteData())!;
        final offset = (point.dy.round() * image.width + point.dx.round()) * 4;
        pixel = Color.fromARGB(
          data.getUint8(offset + 3),
          data.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        );
      });
      return pixel;
    }

    double distance(Color a, Color b) =>
        math.pow(a.r - b.r, 2).toDouble() +
        math.pow(a.g - b.g, 2).toDouble() +
        math.pow(a.b - b.b, 2).toDouble();

    testWidgets('the target takes the colour of its group', (tester) async {
      for (final kind in BallKind.values) {
        final key = GlobalKey();
        await area(
          tester,
          contact: ContactFraction.full,
          target: kind,
          boundary: key,
        );
        final pixel = await pixelAt(tester, key, const Offset(170, 128));
        final nearest = BallKind.values.reduce(
          (a, b) =>
              distance(pixel, BallColors.light.fillOf(a)) <=
                  distance(pixel, BallColors.light.fillOf(b))
              ? a
              : b,
        );
        expect(nearest, kind, reason: 'target $kind, pixel $pixel');
      }
    });

    testWidgets('the cue ball is white', (tester) async {
      final key = GlobalKey();
      await area(
        tester,
        contact: ContactFraction.full,
        target: BallKind.black,
        boundary: key,
      );
      final pixel = await pixelAt(tester, key, const Offset(90, 128));
      expect(
        distance(pixel, BallColors.light.white),
        lessThan(distance(pixel, BallColors.light.black)),
      );
    });
  });

  group('repaints', () {
    Future<CustomPainter> painterOf(
      WidgetTester tester, {
      ContactFraction contact = ContactFraction.half,
      TipPoint tipPoint = TipPoint.center,
      BallKind target = BallKind.red,
      ThemeData? theme,
    }) async {
      await pumpUi(
        tester,
        BallContactDiagram(
          contact: contact,
          tipPoint: tipPoint,
          target: target,
        ),
        theme: theme,
      );
      // Le changement de thème est animé : attendre la valeur finale.
      await tester.pumpAndSettle();
      return tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(BallContactDiagram),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
    }

    testWidgets('not when nothing changes', (tester) async {
      final first = await painterOf(tester);
      final second = await painterOf(tester);

      expect(second.shouldRepaint(first), isFalse);
    });

    testWidgets('when the quantity of ball changes', (tester) async {
      final first = await painterOf(tester);
      final second = await painterOf(tester, contact: ContactFraction.thin);

      expect(second.shouldRepaint(first), isTrue);
    });

    testWidgets('when the tip point changes', (tester) async {
      final first = await painterOf(tester);
      final second = await painterOf(tester, tipPoint: TipPoint.left);

      expect(second.shouldRepaint(first), isTrue);
    });

    testWidgets('when the target ball changes', (tester) async {
      final first = await painterOf(tester);
      final second = await painterOf(tester, target: BallKind.yellow);

      expect(second.shouldRepaint(first), isTrue);
    });

    testWidgets('when the theme changes', (tester) async {
      final first = await painterOf(tester);
      final second = await painterOf(tester, theme: AppTheme.dark());

      expect(second.shouldRepaint(first), isTrue);
    });
  });
}
