import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/cue_side_geometry.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/tip_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tipHeightFactor', () {
    test('is 1 at the top, -1 at the bottom and 0 on the horizontal axis', () {
      expect(tipHeightFactor(TipPoint.top), 1);
      expect(tipHeightFactor(TipPoint.bottom), -1);
      expect(tipHeightFactor(TipPoint.center), 0);
      expect(tipHeightFactor(TipPoint.left), 0);
      expect(tipHeightFactor(TipPoint.right), 0);
    });

    test('diagonals keep the vertical share of a unit direction', () {
      final half = math.sqrt(0.5);

      expect(tipHeightFactor(TipPoint.topLeft), closeTo(half, 1e-12));
      expect(tipHeightFactor(TipPoint.topRight), closeTo(half, 1e-12));
      expect(tipHeightFactor(TipPoint.bottomLeft), closeTo(-half, 1e-12));
      expect(tipHeightFactor(TipPoint.bottomRight), closeTo(-half, 1e-12));
    });
  });

  group('cueElevation', () {
    test('the butt is raised more and more from low to high', () {
      expect(cueElevation(CueHeight.low), 0);
      expect(cueElevation(CueHeight.level), closeTo(10 * math.pi / 180, 1e-12));
      expect(cueElevation(CueHeight.high), closeTo(25 * math.pi / 180, 1e-12));
    });
  });

  group('contactHeight', () {
    test('the contact is 0.680 mm above the cue ball equator (24 / 25.4)', () {
      // Billes posées sur le tapis : centres à 24,0 et 25,4 mm, écart 1,4 mm,
      // s = 49,4 mm ; sin phi = 1,4 / 49,4 ; hauteur = 24,0 x sin phi.
      final contact = contactHeight(cueRadius: 24, objectRadius: 25.4);

      expect(contact.tilt * 180 / math.pi, closeTo(1.6240, 1e-3));
      expect(contact.height, closeTo(0.6802, 1e-3));
      expect(contact.height, greaterThan(0));
    });

    test('equal balls touch exactly on the equator', () {
      final contact = contactHeight(cueRadius: 25.4, objectRadius: 25.4);

      expect(contact.tilt, 0);
      expect(contact.height, 0);
    });

    test('is in the units of the radii given', () {
      final millimetres = contactHeight(cueRadius: 24, objectRadius: 25.4);
      final pixels = contactHeight(cueRadius: 48, objectRadius: 50.8);

      expect(pixels.height, closeTo(2 * millimetres.height, 1e-9));
      expect(pixels.tilt, closeTo(millimetres.tilt, 1e-12));
    });
  });

  group('exaggeratedObjectRadius', () {
    test('x10 grows the 1.4 mm gap to 14 mm: radius 38.0 for 24.0', () {
      expect(
        exaggeratedObjectRadius(cueRadius: 24, objectRadius: 25.4, factor: 10),
        closeTo(38, 1e-9),
      );
    });

    test('x1 keeps the real radius', () {
      expect(
        exaggeratedObjectRadius(cueRadius: 24, objectRadius: 25.4, factor: 1),
        closeTo(25.4, 1e-9),
      );
    });

    test(
      'the exaggerated contact is 5.419 mm above the equator (13.05 deg)',
      () {
        final contact = contactHeight(cueRadius: 24, objectRadius: 38);

        expect(contact.tilt * 180 / math.pi, closeTo(13.0505, 1e-3));
        expect(contact.height, closeTo(5.4194, 1e-3));
      },
    );
  });
}
