import 'package:billard_cfa/shared/ui/cloth_pattern.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme/contrast_test.dart' show contrast;

/// Le motif de tapis passe derrière le titre et la légende de la présentation
/// (U3). Le pire pixel est celui d'un losange : la surface mélangée au bleu
/// tapis à l'opacité du motif. Le texte doit y rester lisible (WCAG AA).
void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    test(
      'the text stays readable on the worst pixel of the pattern ($name)',
      () {
        final scheme = theme.colorScheme;
        final balls = theme.extension<BallColors>()!;
        final worst = Color.alphaBlend(
          balls.cloth.withValues(alpha: ClothPattern.opacity),
          scheme.surface,
        );

        expect(contrast(worst, scheme.onSurface), greaterThanOrEqualTo(4.5));
        expect(
          contrast(worst, scheme.onSurfaceVariant),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }

  test('the pattern stays faint enough to be decoration only', () {
    expect(ClothPattern.opacity, lessThanOrEqualTo(0.08));
  });
}
