import 'package:billard_cfa/shared/ui/ball_chip.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/app_typography.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_ui.dart';

void main() {
  testWidgets('has the requested diameter', (tester) async {
    await pumpUi(tester, const BilliardBall(kind: BallKind.red, diameter: 48));

    expect(tester.getSize(find.byType(BilliardBall)), const Size(48, 48));
  });

  testWidgets('takes the diameter of a ball from the table geometry', (
    tester,
  ) async {
    const geometry = TableGeometry(surface: Rect.fromLTWH(0, 0, 800, 400));
    await pumpUi(
      tester,
      const BilliardBall(kind: BallKind.white, geometry: geometry),
    );

    // Surface de 800 px : 1 case = 100 px, rayon blanche 0,103784 case.
    final size = tester.getSize(find.byType(BilliardBall));
    expect(size.width, closeTo(20.7568, 1e-3));
    expect(size.height, closeTo(20.7568, 1e-3));
  });

  testWidgets('a cue ball is smaller than an object ball on the same table', (
    tester,
  ) async {
    const geometry = TableGeometry(surface: Rect.fromLTWH(0, 0, 800, 400));
    await pumpUi(
      tester,
      const Row(
        children: [
          BilliardBall(kind: BallKind.white, geometry: geometry),
          BilliardBall(kind: BallKind.red, geometry: geometry),
        ],
      ),
    );

    final white = tester.getSize(find.byType(BilliardBall).first).width;
    final red = tester.getSize(find.byType(BilliardBall).last).width;
    expect(white, closeTo(20.7568, 1e-3));
    expect(red, closeTo(21.9676, 1e-3));
    expect(white / red, closeTo(24.0 / 25.4, 1e-6));
  });

  testWidgets('shows the localised letter inside a large ball', (tester) async {
    await pumpUi(
      tester,
      const BilliardBall(kind: BallKind.yellow, diameter: 48),
      locale: const Locale('fr'),
    );

    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('shows the label instead of the letter when given', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const BilliardBall(kind: BallKind.red, diameter: 48, label: '3'),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('R'), findsNothing);
  });

  testWidgets('puts the label beside a ball too small to hold text', (
    tester,
  ) async {
    await pumpUi(
      tester,
      const Center(
        child: BilliardBall(kind: BallKind.red, diameter: 10, label: '5'),
      ),
    );

    expect(find.text('5'), findsOneWidget);
    expect(find.text('R'), findsNothing);
    final ball = tester.getRect(find.byType(BilliardBall));
    expect(tester.getTopLeft(find.text('5')).dx, greaterThan(ball.right));
  });

  testWidgets('can hide the letter', (tester) async {
    await pumpUi(
      tester,
      const BilliardBall(kind: BallKind.red, diameter: 48, showLetter: false),
    );

    expect(find.text('R'), findsNothing);
  });

  testWidgets('is spoken with its localised name and label', (tester) async {
    await pumpUi(
      tester,
      const BilliardBall(kind: BallKind.yellow, diameter: 48),
    );
    expect(find.bySemanticsLabel('Yellow ball'), findsOneWidget);

    await pumpUi(
      tester,
      const BilliardBall(kind: BallKind.black, diameter: 48, label: '2'),
      locale: const Locale('fr'),
    );
    expect(find.bySemanticsLabel('Bille noire, 2'), findsOneWidget);
  });

  group('painted colour', () {
    // Couleur réellement rasterisée au centre de la bille.
    Future<Color> centerPixel(
      WidgetTester tester,
      BallKind kind,
      ThemeData theme,
    ) async {
      final key = GlobalKey();
      await pumpUi(
        tester,
        Center(
          child: RepaintBoundary(
            key: key,
            child: BilliardBall(kind: kind, diameter: 60, showLetter: false),
          ),
        ),
        theme: theme,
      );
      late Color pixel;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = (await image.toByteData())!;
        final x = image.width ~/ 2;
        final y = image.height ~/ 2;
        final offset = (y * image.width + x) * 4;
        pixel = Color.fromARGB(
          data.getUint8(offset + 3),
          data.getUint8(offset),
          data.getUint8(offset + 1),
          data.getUint8(offset + 2),
        );
      });
      return pixel;
    }

    double distance(Color a, Color b) {
      final dr = a.r - b.r;
      final dg = a.g - b.g;
      final db = a.b - b.b;
      return dr * dr + dg * dg + db * db;
    }

    for (final (name, theme, palette) in [
      ('light', AppTheme.light(), BallColors.light),
      ('dark', AppTheme.dark(), BallColors.dark),
    ]) {
      testWidgets('each kind is painted with its own $name colour', (
        tester,
      ) async {
        for (final kind in BallKind.values) {
          final pixel = await centerPixel(tester, kind, theme);
          final nearest = BallKind.values.reduce(
            (a, b) =>
                distance(pixel, palette.fillOf(a)) <=
                    distance(pixel, palette.fillOf(b))
                ? a
                : b,
          );
          expect(nearest, kind, reason: '$name $kind pixel $pixel');
        }
      });
    }

    testWidgets('the theme palette is the one the ball reads', (tester) async {
      await pumpUi(
        tester,
        const BilliardBall(kind: BallKind.red, diameter: 48),
        theme: AppTheme.dark(),
      );
      final context = tester.element(find.byType(BilliardBall));
      expect(
        Theme.of(context).extension<BallColors>()!.red,
        BallColors.dark.red,
      );
    });
  });

  group('letter threshold', () {
    Future<void> pumpBall(WidgetTester tester, double diameter) => pumpUi(
      tester,
      Center(
        child: BilliardBall(
          kind: BallKind.red,
          diameter: diameter,
          label: 'x4',
        ),
      ),
    );

    testWidgets('27 px: the label is written beside the ball', (tester) async {
      await pumpBall(tester, 27);
      final label = tester.getTopLeft(find.text('x4'));
      final ball = tester.getTopRight(find.byType(BilliardBall));
      expect(label.dx, greaterThanOrEqualTo(ball.dx));
    });

    for (final size in [28.0, 29.0]) {
      testWidgets('$size px: the label is inside the ball', (tester) async {
        await pumpBall(tester, size);
        final label = tester.getCenter(find.text('x4'));
        final ball = tester.getRect(find.byType(BilliardBall));
        expect(ball.contains(label), isTrue);
      });
    }
  });

  testWidgets('keeps a legible letter at a large text scale', (tester) async {
    await pumpUi(
      tester,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Center(child: BilliardBall(kind: BallKind.black, diameter: 48)),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('B'), findsOneWidget);
    final style = tester.widget<Text>(find.text('B')).style!;
    expect(style.fontSize, greaterThanOrEqualTo(AppTypography.minTextSize));
  });

  testWidgets('the letter takes the contrasting colour of its ball', (
    tester,
  ) async {
    for (final kind in BallKind.values) {
      await pumpUi(
        tester,
        Center(child: BilliardBall(kind: kind, diameter: 48)),
      );
      final style = tester.widget<Text>(find.byType(Text)).style!;
      expect(style.color, BallColors.light.onFillOf(kind), reason: '$kind');
    }
  });

  test('maps each kind to its colours', () {
    expect(BallColors.light.fillOf(BallKind.red), BallColors.light.red);
    expect(BallColors.light.fillOf(BallKind.yellow), BallColors.light.yellow);
    expect(BallColors.light.fillOf(BallKind.black), BallColors.light.black);
    expect(BallColors.light.fillOf(BallKind.white), BallColors.light.white);
    expect(BallColors.light.onFillOf(BallKind.red), BallColors.light.onRed);
    expect(
      BallColors.light.onFillOf(BallKind.yellow),
      BallColors.light.onYellow,
    );
    expect(BallColors.light.onFillOf(BallKind.black), BallColors.light.onBlack);
    expect(BallColors.light.onFillOf(BallKind.white), BallColors.light.onWhite);
  });
}
