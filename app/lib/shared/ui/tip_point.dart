import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:billard_cfa/shared/lib/tip_point.dart';

export 'package:billard_cfa/shared/lib/tip_point.dart';

/// Direction géométrique d'un [TipPoint] dans le repère du dessin.
extension TipPointDirection on TipPoint {
  /// Direction du point par rapport au centre (unité = rayon, 0 au centre,
  /// y vers le bas). Les diagonales sont à distance 1 du centre.
  Offset get direction {
    const diagonal = math.sqrt1_2;
    return switch (this) {
      TipPoint.center => Offset.zero,
      TipPoint.top => const Offset(0, -1),
      TipPoint.bottom => const Offset(0, 1),
      TipPoint.left => const Offset(-1, 0),
      TipPoint.right => const Offset(1, 0),
      TipPoint.topLeft => const Offset(-diagonal, -diagonal),
      TipPoint.topRight => const Offset(diagonal, -diagonal),
      TipPoint.bottomLeft => const Offset(-diagonal, diagonal),
      TipPoint.bottomRight => const Offset(diagonal, diagonal),
    };
  }
}
