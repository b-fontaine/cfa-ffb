import 'dart:math' as math;

import 'package:billard_cfa/shared/ui/theme/app_color_schemes.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Luminance relative WCAG 2.x (sRGB), recalculée ici sans Flutter.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

typedef _Pair = (String, Color, Color);

List<_Pair> _textPairs(ColorScheme s, BallColors balls, StatusColors status) =>
    [
      ('primary', s.primary, s.onPrimary),
      ('primaryContainer', s.primaryContainer, s.onPrimaryContainer),
      ('secondary', s.secondary, s.onSecondary),
      ('secondaryContainer', s.secondaryContainer, s.onSecondaryContainer),
      ('tertiary', s.tertiary, s.onTertiary),
      ('tertiaryContainer', s.tertiaryContainer, s.onTertiaryContainer),
      ('error', s.error, s.onError),
      ('errorContainer', s.errorContainer, s.onErrorContainer),
      ('surface', s.surface, s.onSurface),
      ('surface/variant', s.surface, s.onSurfaceVariant),
      ('surfaceContainerLowest', s.surfaceContainerLowest, s.onSurface),
      ('surfaceContainerLow', s.surfaceContainerLow, s.onSurface),
      ('surfaceContainer', s.surfaceContainer, s.onSurface),
      ('surfaceContainerHigh', s.surfaceContainerHigh, s.onSurface),
      ('surfaceContainerHighest', s.surfaceContainerHighest, s.onSurface),
      (
        'surfaceContainerHighest/variant',
        s.surfaceContainerHighest,
        s.onSurfaceVariant,
      ),
      ('inverseSurface', s.inverseSurface, s.onInverseSurface),
      ('success', status.success, status.onSuccess),
      ('attention', status.attention, status.onAttention),
      ('ball red', balls.red, balls.onRed),
      ('ball yellow', balls.yellow, balls.onYellow),
      ('ball black', balls.black, balls.onBlack),
      ('ball white', balls.white, balls.onWhite),
      ('cloth', balls.cloth, balls.onCloth),
    ];

void main() {
  final schemes = <String, (ColorScheme, BallColors, StatusColors)>{
    'light': (AppColorSchemes.light, BallColors.light, StatusColors.light),
    'dark': (AppColorSchemes.dark, BallColors.dark, StatusColors.dark),
  };

  for (final entry in schemes.entries) {
    final (scheme, balls, status) = entry.value;

    test('${entry.key}: every text pair reaches WCAG AA (4.5:1)', () {
      final failures = <String>[
        for (final (name, background, foreground) in _textPairs(
          scheme,
          balls,
          status,
        ))
          if (contrast(background, foreground) < 4.5)
            '$name = ${contrast(background, foreground).toStringAsFixed(2)}',
      ];

      expect(failures, isEmpty);
    });

    test('${entry.key}: component borders reach 3:1 against the surface', () {
      expect(contrast(scheme.surface, scheme.outline), greaterThanOrEqualTo(3));
      expect(
        contrast(scheme.surfaceContainerLowest, scheme.outline),
        greaterThanOrEqualTo(3),
      );
    });
  }

  test('the contrast helper matches known WCAG values', () {
    expect(
      contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(
      contrast(const Color(0xFF1964AF), const Color(0xFFFFFFFF)),
      closeTo(6.03, 0.02),
    );
  });

  test('the check fails on a low-contrast pair', () {
    expect(
      contrast(const Color(0xFF3297FF), const Color(0xFFFFFFFF)),
      lessThan(4.5),
    );
  });
}
