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
}
