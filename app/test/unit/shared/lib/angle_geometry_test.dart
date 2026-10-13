import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/angle_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('angleBetween', () {
    test('two perpendicular rays make a right angle', () {
      final angle = angleBetween(
        vertex: const math.Point(4, 2),
        a: const math.Point(6, 2),
        b: const math.Point(4, 0),
      );

      expect(angle, closeTo(math.pi / 2, 1e-12));
    });

    test('a ray and its diagonal make 45 degrees', () {
      final angle = angleBetween(
        vertex: const math.Point(0, 0),
        a: const math.Point(1, 0),
        b: const math.Point(1, 1),
      );

      expect(angle, closeTo(math.pi / 4, 1e-12));
    });

    test('opposite rays make a straight angle', () {
      final angle = angleBetween(
        vertex: const math.Point(3, 1),
        a: const math.Point(1, 1),
        b: const math.Point(7, 1),
      );

      expect(angle, closeTo(math.pi, 1e-12));
    });

    test('does not depend on the order of the rays', () {
      const vertex = math.Point<double>(4, 4);
      final a = math.Point<double>(4 + math.sqrt(3), 3);
      const b = math.Point<double>(4, 2);

      expect(
        angleBetween(vertex: vertex, a: a, b: b),
        closeTo(angleBetween(vertex: vertex, a: b, b: a), 1e-12),
      );
    });

    test('is zero when a ray has no length', () {
      final angle = angleBetween(
        vertex: const math.Point(1, 1),
        a: const math.Point(1, 1),
        b: const math.Point(3, 1),
      );

      expect(angle, 0);
    });
  });

  group('angleDegrees', () {
    test('rounds to whole degrees: sqrt(3) over 1 is 30, so 60 with a '
        'vertical ray', () {
      // Rayon a : (sqrt 3, -1) soit 30° au-dessus de l'axe ; rayon b : (0, -2),
      // vertical : 90° - 30° = 60°.
      final degrees = angleDegrees(
        vertex: const math.Point(4, 4),
        a: math.Point(4 + math.sqrt(3), 3),
        b: const math.Point(4, 2),
      );

      expect(degrees, 60);
    });

    test('a right angle is exactly 90', () {
      expect(
        angleDegrees(
          vertex: const math.Point(1, 1),
          a: const math.Point(5, 1),
          b: const math.Point(1, 3),
        ),
        90,
      );
    });
  });
}
