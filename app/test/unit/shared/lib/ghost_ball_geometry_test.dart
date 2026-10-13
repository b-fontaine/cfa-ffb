import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/lib/ghost_ball_geometry.dart';
import 'package:billard_cfa/shared/lib/table_pocket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const object = math.Point<double>(4, 2);

  test('puts the ghost ball two radii behind the object, on the line', () {
    // Pocket tr = (8, 0) : the line object -> pocket is (4, -2), |.| = sqrt 20.
    final ghost = ghostBallPosition(object: object, pocket: TablePocket.tr);

    expect(ghost.x, closeTo(3.8211, 1e-4));
    expect(ghost.y, closeTo(2.0894, 1e-4));
  });

  test('puts the ghost ball straight behind an object facing a pocket', () {
    // Object (4, 2), pocket tm (4, 0): the ghost is 0.2 below the object.
    final ghost = ghostBallPosition(object: object, pocket: TablePocket.tm);

    expect(ghost.x, closeTo(4.0, 1e-9));
    expect(ghost.y, closeTo(2.2, 1e-9));
  });

  test('an object sitting on the pocket keeps a defined ghost ball', () {
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

  test('a straight shot has a full ball quantity (theta = 0)', () {
    // Pocket tm = (4, 0): object (4, 2) straight above; cue below on x = 4.
    final quantity = contactQuantity(
      cue: const math.Point(4, 4),
      object: object,
      pocket: TablePocket.tm,
    );

    expect(quantity, closeTo(1.0, 1e-9));
  });

  test('a 30 degree cut gives a half ball (1 - sin 30 = 0.5)', () {
    // Build a cue position so that the angle (ghost - cue) / (pocket - object)
    // is exactly 30 degrees: rotate the object -> pocket direction.
    // Direction (0, -1) from the object at (4, 2).
    const pocket = TablePocket.tm;
    final ghost = ghostBallPosition(object: object, pocket: pocket);
    const theta = 30 * math.pi / 180;
    // Cue at distance 3 behind the ghost, rotated by theta from the line.
    final cue = math.Point<double>(
      ghost.x - 3 * math.sin(theta),
      ghost.y + 3 * math.cos(theta),
    );

    expect(
      cutAngle(cue: cue, object: object, pocket: pocket),
      closeTo(theta, 1e-9),
    );
    expect(
      contactQuantity(cue: cue, object: object, pocket: pocket),
      closeTo(0.5, 1e-9),
    );
  });

  test('quantity labels match the nominal overlaps within 0.07', () {
    const pocket = TablePocket.tm;
    final ghost = ghostBallPosition(object: object, pocket: pocket);
    // Cut angles from the FORMAT: 0, 14.5, 30, 48.6 degrees.
    final expected = {
      0.0: ContactFraction.full,
      14.5: ContactFraction.threeQuarter,
      30.0: ContactFraction.half,
      48.6: ContactFraction.quarter,
    };
    for (final MapEntry(key: degrees, value: fraction) in expected.entries) {
      final theta = degrees * math.pi / 180;
      final cue = math.Point<double>(
        ghost.x - 3 * math.sin(theta),
        ghost.y + 3 * math.cos(theta),
      );
      final quantity = contactQuantity(
        cue: cue,
        object: object,
        pocket: pocket,
      );

      expect(
        (quantity - fraction.overlap).abs(),
        lessThanOrEqualTo(0.07),
        reason: '$degrees deg -> $fraction',
      );
    }
  });

  test('a cut beyond 90 degrees is clamped to a zero quantity', () {
    // Cue on the far side of the pocket line: sin(theta) >= 1.
    final quantity = contactQuantity(
      cue: const math.Point(4, -10),
      object: object,
      pocket: TablePocket.tm,
    );

    expect(quantity, 0.0);
  });

  group('cut angle and quantity at the bounds', () {
    const pocket = TablePocket.tm;
    math.Point<double> cueAt(double degrees) {
      final ghost = ghostBallPosition(object: object, pocket: pocket);
      final theta = degrees * math.pi / 180;
      return math.Point<double>(
        ghost.x - 3 * math.sin(theta),
        ghost.y + 3 * math.cos(theta),
      );
    }

    test('exactly 90 degrees gives a zero quantity', () {
      expect(
        contactQuantity(cue: cueAt(90), object: object, pocket: pocket),
        0.0,
      );
    });

    test('a cue on the other side of the line gives the same quantity', () {
      expect(
        contactQuantity(cue: cueAt(-30), object: object, pocket: pocket),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('ghost aim consistency', () {
    const pocket = TablePocket.tm;
    final ghost = ghostBallPosition(object: object, pocket: pocket);
    // Cue at 30 degrees from the object -> pocket line : a half ball.
    final halfCue = math.Point<double>(
      ghost.x - 3 * math.sin(30 * math.pi / 180),
      ghost.y + 3 * math.cos(30 * math.pi / 180),
    );

    test('accepts the label that matches the geometry', () {
      expect(
        isGhostAimConsistent(
          cue: halfCue,
          object: object,
          pocket: pocket,
          fraction: ContactFraction.half,
        ),
        isTrue,
      );
    });

    test('rejects a half-ball geometry labelled full', () {
      expect(
        isGhostAimConsistent(
          cue: halfCue,
          object: object,
          pocket: pocket,
          fraction: ContactFraction.full,
        ),
        isFalse,
      );
    });

    test('reports the gap between the geometry and the label', () {
      expect(
        ghostAimDeviation(
          cue: halfCue,
          object: object,
          pocket: pocket,
          fraction: ContactFraction.full,
        ),
        closeTo(0.5, 1e-9),
      );
    });

    test('the tolerance is 0.07', () {
      expect(ghostAimTolerance, 0.07);
    });
  });
}
