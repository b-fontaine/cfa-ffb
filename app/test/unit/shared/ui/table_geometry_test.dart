import 'dart:ui';

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

    test('a ball is a tenth of a cell in radius', () {
      expect(TableGeometry.ballRadius, 0.1);
      expect(geometry.ballRadiusPx, closeTo(5, 1e-9));
    });

    test('the head string is at x = 2', () {
      expect(TableGeometry.headStringX, 2);
      expect(geometry.toPixel(const Offset(2, 0)).dx, 150);
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

    test('ballRect is a square centred on the ball', () {
      final rect = geometry.ballRect(const Offset(2, 1));

      expect(rect.center, const Offset(150, 70));
      expect(rect.width, closeTo(10, 1e-9));
      expect(rect.height, closeTo(10, 1e-9));
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
        expect(g.ballRadiusPx, 0);
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
