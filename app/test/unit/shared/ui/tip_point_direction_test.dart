import 'dart:math' as math;

import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the four diagonals are unit vectors towards their corner', () {
    final expected = {
      TipPoint.topLeft: const Offset(-1, -1),
      TipPoint.topRight: const Offset(1, -1),
      TipPoint.bottomLeft: const Offset(-1, 1),
      TipPoint.bottomRight: const Offset(1, 1),
    };
    for (final MapEntry(key: point, value: corner) in expected.entries) {
      expect(point.direction.distance, closeTo(1, 1e-9), reason: '$point');
      expect(
        point.direction,
        offsetMoreOrLessEquals(corner / math.sqrt2, epsilon: 1e-9),
      );
    }
  });

  test('every tip point has its own localised label', () async {
    for (final locale in const [Locale('fr'), Locale('en')]) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final labels = {
        for (final point in TipPoint.values)
          BallContactDiagram.tipLabel(l10n, point),
      };

      expect(labels, hasLength(TipPoint.values.length), reason: '$locale');
    }
  });
}
