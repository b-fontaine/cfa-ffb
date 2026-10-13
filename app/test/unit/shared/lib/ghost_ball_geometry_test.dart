import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/blackball_dimensions.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/ghost_ball_geometry.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:flutter_test/flutter_test.dart';

// Valeurs attendues calculées à la main (plan tailles-et-illustrations § 5.2) :
// s = r_c + r_o = (24,0 + 25,4) / 231,25 = 0,213622 case.
const _s = 0.213622;
double _deg(double radians) => radians * 180 / math.pi;

void main() {
  const object = math.Point<double>(4, 2);

  group('ghost ball (G = O - s . unit(P - O), s = r_c + r_o)', () {
    test('is s behind the object when the pocket is straight ahead', () {
      // O = (4, 2), P = tm = (4, 0) : G = (4, 2 + 0.213622).
      final ghost = ghostBallPosition(object: object, pocket: TablePocket.tm);

      expect(ghost.x, closeTo(4, 1e-9));
      expect(ghost.y, closeTo(2 + _s, 1e-6));
    });

    test('is not the old model with two object radii (0.2197)', () {
      final ghost = ghostBallPosition(object: object, pocket: TablePocket.tm);

      expect(
        ghost.y,
        isNot(closeTo(2 + 2 * BlackballDimensions.objectBallRadius, 1e-3)),
      );
      expect(
        (ghost.y - 2).abs(),
        lessThan(2 * BlackballDimensions.objectBallRadius),
      );
      expect(ghost.y - 2, closeTo(0.213622, 1e-6));
    });

    test('follows a diagonal towards the top left pocket', () {
      // O = (1, 1), P = (0, 0) : G = O + (s / sqrt 2)(1, 1) = (1.15105, ...).
      final ghost = ghostBallPosition(
        object: const math.Point(1, 1),
        pocket: TablePocket.tl,
      );

      expect(ghost.x, closeTo(1.15105, 1e-4));
      expect(ghost.y, closeTo(1.15105, 1e-4));
    });

    test('follows a diagonal towards the bottom right pocket', () {
      // O = (6, 2), P = (8, 4) : G = O - (s / sqrt 2)(1, 1) = (5.84895, ...).
      final ghost = ghostBallPosition(
        object: const math.Point(6, 2),
        pocket: TablePocket.br,
      );

      expect(ghost.x, closeTo(5.84895, 1e-4));
      expect(ghost.y, closeTo(1.84895, 1e-4));
    });

    test('keeps a defined ghost ball for an object sitting on the pocket', () {
      final ghost = ghostBallPosition(
        object: TablePocket.tm.point,
        pocket: TablePocket.tm,
      );

      expect(ghost, TablePocket.tm.point);
      expect(
        contactQuantity(
          cue: const math.Point(4, 3),
          object: TablePocket.tm.point,
          pocket: TablePocket.tm,
        ).isNaN,
        isFalse,
      );
    });

    test('uses the sizes given: WEPF 47.6 mm gives 0.212757', () {
      final ghost = ghostBallPosition(
        object: object,
        pocket: TablePocket.tm,
        sizes: const BallSizes(cueDiameterMm: 47.6),
      );

      expect(ghost.y - 2, closeTo(0.212757, 1e-6));
    });

    test('with equal balls it is back to 2 r_o = 0.219676 (regression)', () {
      final ghost = ghostBallPosition(
        object: object,
        pocket: TablePocket.tm,
        sizes: const BallSizes(cueDiameterMm: 50.8),
      );

      expect(ghost.y - 2, closeTo(0.219676, 1e-6));
    });
  });

  group('aim offset d = distance from the aim line to the object centre', () {
    test('full ball is 0', () {
      expect(ContactFraction.full.aimOffset(), 0);
    });

    test('three quarters is r_o / 2 = 0.054919', () {
      expect(ContactFraction.threeQuarter.aimOffset(), closeTo(0.054919, 1e-6));
    });

    test('half is r_o (the cue centre passes the tangent) = 0.109838', () {
      expect(ContactFraction.half.aimOffset(), closeTo(0.109838, 1e-6));
    });

    test('quarter is r_o + r_c / 2, measured from the cue ball = 0.161730', () {
      // 0.109838 + 0.103784 / 2 = 0.161730 (and not r_o * 1.5 = 0.164757).
      expect(ContactFraction.quarter.aimOffset(), closeTo(0.161730, 1e-6));
      expect(
        ContactFraction.quarter.aimOffset(),
        isNot(closeTo(1.5 * BlackballDimensions.objectBallRadius, 1e-4)),
      );
    });

    test('thin is 0.95 s = 0.202941', () {
      expect(ContactFraction.thin.aimOffset(), closeTo(0.202941, 1e-6));
    });

    test('is strictly decreasing in coverage', () {
      final offsets = [for (final f in ContactFraction.values) f.aimOffset()];

      for (var i = 1; i < offsets.length; i++) {
        expect(offsets[i], greaterThan(offsets[i - 1]));
      }
    });

    test(
      'nominal angles are asin(d / s): 0, 14.90, 30.94, 49.21, 71.81 deg',
      () {
        final angles = [
          for (final f in ContactFraction.values) _deg(f.nominalCutAngle()),
        ];

        expect(angles[0], closeTo(0, 1e-9));
        expect(angles[1], closeTo(14.90, 0.01));
        expect(angles[2], closeTo(30.94, 0.01));
        expect(angles[3], closeTo(49.21, 0.01));
        expect(angles[4], closeTo(71.81, 0.01));
      },
    );

    test('with equal balls the half ball is exactly 30 degrees', () {
      const equal = BallSizes(cueDiameterMm: 50.8);

      expect(
        _deg(ContactFraction.half.nominalCutAngle(equal)),
        closeTo(30.0, 1e-9),
      );
      expect(
        _deg(ContactFraction.quarter.nominalCutAngle(equal)),
        closeTo(48.59, 0.01),
      );
      expect(
        _deg(ContactFraction.threeQuarter.nominalCutAngle(equal)),
        closeTo(14.48, 0.01),
      );
    });
  });

  group('cut angle, aim distance and quantity', () {
    const pocket = TablePocket.tm;
    math.Point<double> cueAt(double degrees) {
      final ghost = ghostBallPosition(object: object, pocket: pocket);
      final theta = degrees * math.pi / 180;
      return math.Point<double>(
        ghost.x - 3 * math.sin(theta),
        ghost.y + 3 * math.cos(theta),
      );
    }

    test('a straight shot has a zero angle, a zero offset, a full ball', () {
      final cue = cueAt(0);

      expect(
        cutAngle(cue: cue, object: object, pocket: pocket),
        closeTo(0, 1e-9),
      );
      expect(
        aimDistance(cue: cue, object: object, pocket: pocket),
        closeTo(0, 1e-9),
      );
      expect(
        contactQuantity(cue: cue, object: object, pocket: pocket),
        closeTo(1, 1e-9),
      );
    });

    test('rebuilds a 30.94 degree cut from the cue position', () {
      final cue = cueAt(30.94);

      expect(
        _deg(cutAngle(cue: cue, object: object, pocket: pocket)),
        closeTo(30.94, 1e-6),
      );
    });

    test('aim distance is s sin(theta): half ball gives 0.109838', () {
      final cue = cueAt(30.94);

      expect(
        aimDistance(cue: cue, object: object, pocket: pocket),
        closeTo(0.109838, 1e-4),
      );
    });

    test('aimDistance of a 90 degree or more cut is s = 0.213622', () {
      expect(
        aimDistance(cue: cueAt(90), object: object, pocket: pocket),
        closeTo(_s, 1e-6),
      );
      expect(
        aimDistance(
          cue: const math.Point(4, -10),
          object: object,
          pocket: pocket,
        ),
        closeTo(_s, 1e-6),
      );
    });

    test('aimDistance just under 90 degrees is s sin(89.9) = 0.2136213', () {
      expect(
        aimDistance(cue: cueAt(89.9), object: object, pocket: pocket),
        closeTo(0.2136213, 1e-7),
      );
    });

    test('quantity is 1 - sin(theta): 1, 0.743, 0.486, 0.243', () {
      final expected = {0.0: 1.0, 14.90: 0.743, 30.94: 0.486, 49.21: 0.243};
      for (final MapEntry(key: degrees, value: quantity) in expected.entries) {
        expect(
          contactQuantity(cue: cueAt(degrees), object: object, pocket: pocket),
          closeTo(quantity, 1e-3),
          reason: '$degrees deg',
        );
      }
    });

    test('a cut of 90 degrees or more gives a zero quantity', () {
      expect(
        contactQuantity(cue: cueAt(90), object: object, pocket: pocket),
        0,
      );
      expect(
        contactQuantity(
          cue: const math.Point(4, -10),
          object: object,
          pocket: pocket,
        ),
        0,
      );
    });

    test('a cue on the other side of the line gives the same quantity', () {
      expect(
        contactQuantity(cue: cueAt(-30.94), object: object, pocket: pocket),
        closeTo(0.486, 1e-3),
      );
    });
  });

  group('ghost aim consistency (V17: |d - d_nominal| <= 0.07 s)', () {
    const pocket = TablePocket.tm;
    final ghost = ghostBallPosition(object: object, pocket: pocket);
    math.Point<double> cueAt(double degrees) {
      final theta = degrees * math.pi / 180;
      return math.Point<double>(
        ghost.x - 3 * math.sin(theta),
        ghost.y + 3 * math.cos(theta),
      );
    }

    test('the tolerance is 0.07 s = 0.014954 case', () {
      expect(ghostAimTolerance(), closeTo(0.014954, 1e-6));
    });

    test('accepts the nominal geometry of every quantity', () {
      for (final fraction in ContactFraction.values) {
        final degrees = _deg(fraction.nominalCutAngle());
        expect(
          isGhostAimConsistent(
            cue: cueAt(degrees),
            object: object,
            pocket: pocket,
            fraction: fraction,
          ),
          isTrue,
          reason: fraction.name,
        );
      }
    });

    test('reports no gap for the nominal geometry', () {
      expect(
        ghostAimDeviation(
          cue: cueAt(30.94),
          object: object,
          pocket: pocket,
          fraction: ContactFraction.half,
        ),
        closeTo(0, 1e-4),
      );
    });

    test('rejects a half ball geometry labelled full', () {
      expect(
        isGhostAimConsistent(
          cue: cueAt(30.94),
          object: object,
          pocket: pocket,
          fraction: ContactFraction.full,
        ),
        isFalse,
      );
    });

    test('reports the gap between the geometry and the label, in cases', () {
      expect(
        ghostAimDeviation(
          cue: cueAt(30.94),
          object: object,
          pocket: pocket,
          fraction: ContactFraction.full,
        ),
        closeTo(0.109838, 1e-4),
      );
    });

    test('neighbouring labels are further apart than twice the tolerance', () {
      final offsets = [for (final f in ContactFraction.values) f.aimOffset()];
      var minimum = double.infinity;
      for (var i = 1; i < offsets.length; i++) {
        minimum = math.min(minimum, offsets[i] - offsets[i - 1]);
      }

      expect(minimum / _s, closeTo(0.19, 0.005));
      expect(minimum, greaterThan(2 * ghostAimTolerance()));
    });
  });
}
