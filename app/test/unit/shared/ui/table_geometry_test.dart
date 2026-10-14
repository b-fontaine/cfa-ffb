import 'dart:ui';

import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/table_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TableGeometry', () {
    const geometry = TableGeometry(surface: Rect.fromLTWH(50, 20, 400, 200));

    test('one cell is a quarter of the width and a fourth of the height', () {
      expect(geometry.unit, 50);
    });

    test('converts table coordinates to pixels', () {
      expect(geometry.toPixel(Offset.zero), const Offset(50, 20));
      expect(geometry.toPixel(const Offset(8, 4)), const Offset(450, 220));
      expect(geometry.toPixel(const Offset(2, 1)), const Offset(150, 70));
    });

    test('converts pixels back to table coordinates', () {
      expect(geometry.toTable(const Offset(150, 70)), const Offset(2, 1));
      const point = Offset(3.3, 1.7);
      final back = geometry.toTable(geometry.toPixel(point));
      expect(back.dx, closeTo(point.dx, 1e-9));
      expect(back.dy, closeTo(point.dy, 1e-9));
    });

    test('an object ball has a radius of 25.4 mm = 0.109838 cell', () {
      expect(TableGeometry.objectBallRadius, closeTo(0.109838, 1e-6));
      expect(geometry.radiusPxOf(BallKind.red), closeTo(5.4919, 1e-3));
      expect(geometry.radiusPxOf(BallKind.yellow), closeTo(5.4919, 1e-3));
      expect(geometry.radiusPxOf(BallKind.black), closeTo(5.4919, 1e-3));
    });

    test('the cue ball has a radius of 24.0 mm = 0.103784 cell', () {
      expect(TableGeometry.cueBallRadius, closeTo(0.103784, 1e-6));
      expect(geometry.radiusPxOf(BallKind.white), closeTo(5.1892, 1e-3));
      expect(geometry.ghostRadiusPx, geometry.radiusPxOf(BallKind.white));
    });

    test('on an 800 px wide surface the radii are 10.3784 and 10.9838 px', () {
      const wide = TableGeometry(surface: Rect.fromLTWH(0, 0, 800, 400));

      expect(wide.radiusPxOf(BallKind.white), closeTo(10.3784, 1e-3));
      expect(wide.radiusPxOf(BallKind.red), closeTo(10.9838, 1e-3));
    });

    test('the cue ball is always smaller, at any scale', () {
      for (final width in [40.0, 360.0, 800.0, 1280.0]) {
        final g = TableGeometry(surface: Rect.fromLTWH(0, 0, width, width / 2));

        expect(
          g.radiusPxOf(BallKind.white) / g.radiusPxOf(BallKind.red),
          closeTo(24.0 / 25.4, 1e-9),
        );
      }
    });

    test('a pocket opens 76.2 mm = 0.329514 cell (radius 0.164757)', () {
      expect(TableGeometry.pocketRadius, closeTo(0.164757, 1e-6));
      expect(geometry.pocketRadiusPx, closeTo(8.2379, 1e-3));
    });

    test('the head string is at x = 1.6', () {
      expect(TableGeometry.headStringX, closeTo(1.6, 1e-12));
      expect(
        geometry.toPixel(const Offset(TableGeometry.headStringX, 0)).dx,
        closeTo(130, 1e-9),
      );
    });

    test('exposes the six pocket centres at the corners and sides', () {
      expect(geometry.pocketCenter(TablePocket.tl), const Offset(50, 20));
      expect(geometry.pocketCenter(TablePocket.tm), const Offset(250, 20));
      expect(geometry.pocketCenter(TablePocket.tr), const Offset(450, 20));
      expect(geometry.pocketCenter(TablePocket.bl), const Offset(50, 220));
      expect(geometry.pocketCenter(TablePocket.bm), const Offset(250, 220));
      expect(geometry.pocketCenter(TablePocket.br), const Offset(450, 220));
      expect(TablePocket.values, hasLength(6));
    });

    test('pockets are also given in table coordinates', () {
      expect(TablePocket.tm.position, const Offset(4, 0));
      expect(TablePocket.br.position, const Offset(8, 4));
    });

    test('the table rectangle adds the rails around the surface', () {
      final table = geometry.tableRect;

      expect(table.left, 50 - 0.5 * 50);
      expect(table.right, 450 + 0.5 * 50);
      expect(table.top, 20 - 0.5 * 50);
      expect(table.bottom, 220 + 0.5 * 50);
    });

    test('ballRect is a square centred on the ball, sized by its kind', () {
      final red = geometry.ballRect(const Offset(2, 1), BallKind.red);
      final white = geometry.ballRect(const Offset(2, 1), BallKind.white);

      expect(red.center, const Offset(150, 70));
      expect(white.center, const Offset(150, 70));
      expect(red.width, closeTo(10.9838, 1e-3));
      expect(red.height, closeTo(10.9838, 1e-3));
      expect(white.width, closeTo(10.3784, 1e-3));
      expect(white.height, closeTo(10.3784, 1e-3));
    });
  });

  group('TableGeometry.fitting', () {
    test('fills the width of a wide area and centres vertically', () {
      final g = TableGeometry.fitting(const Size(900, 900));

      // 8 cells + 2 rails of 0.5 = 9 units across.
      expect(g.unit, closeTo(100, 1e-9));
      expect(g.surface.width, closeTo(800, 1e-9));
      expect(g.surface.height, closeTo(400, 1e-9));
      expect(g.tableRect.left, closeTo(0, 1e-9));
      expect(g.tableRect.center.dy, closeTo(450, 1e-9));
    });

    test('is limited by the height of a short area', () {
      final g = TableGeometry.fitting(const Size(1000, 250));

      // 4 cells + 2 rails of 0.5 = 5 units tall.
      expect(g.unit, closeTo(50, 1e-9));
      expect(g.tableRect.height, closeTo(250, 1e-9));
      expect(g.tableRect.center.dx, closeTo(500, 1e-9));
    });

    test('keeps the 2:1 surface ratio', () {
      final g = TableGeometry.fitting(const Size(333, 777));

      expect(g.surface.width / g.surface.height, closeTo(2, 1e-9));
    });

    test('an empty area gives an empty geometry without error', () {
      final g = TableGeometry.fitting(Size.zero);

      expect(g.unit, 0);
      expect(g.toPixel(const Offset(3, 2)), Offset.zero);
    });

    test('a zero dimension gives a zero unit, never NaN', () {
      for (final size in const [Size(0, 300), Size(300, 0)]) {
        final g = TableGeometry.fitting(size);
        expect(g.unit, 0, reason: '$size');
        expect(g.toPixel(const Offset(3, 2)).dx.isNaN, isFalse);
        expect(g.toPixel(const Offset(3, 2)).dy.isNaN, isFalse);
        expect(g.radiusPxOf(BallKind.red), 0);
        expect(g.radiusPxOf(BallKind.white), 0);
      }
    });

    test('toTable of an empty geometry is the origin, not a division', () {
      expect(
        TableGeometry.fitting(Size.zero).toTable(const Offset(5, 5)),
        Offset.zero,
      );
    });

    test('a point outside the table is converted, not clamped', () {
      final g = TableGeometry.fitting(const Size(500, 250));
      // Le refus des points hors table se fait dans DiagramTimeline.
      final left = g.toPixel(const Offset(-1, 5));
      expect(left.dx, lessThan(g.surface.left));
      expect(left.dy, greaterThan(g.surface.bottom));
      expect(g.toTable(left), offsetMoreOrLessEquals(const Offset(-1, 5)));
      final right = g.toPixel(const Offset(9, -1));
      expect(right.dx, greaterThan(g.surface.right));
      expect(right.dy, lessThan(g.surface.top));
    });
  });
}
