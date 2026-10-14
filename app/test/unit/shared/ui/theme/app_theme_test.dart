import 'package:billard_cfa/shared/ui/theme/app_color_schemes.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:billard_cfa/shared/ui/theme/app_typography.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/brand_colors.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColorSchemes', () {
    test(
      'uses the FFB blue as light primary and the cloth blue as secondary',
      () {
        expect(AppColorSchemes.light.primary, const Color(0xFF1964AF));
        expect(AppColorSchemes.light.secondary, const Color(0xFF2F6B8A));
        expect(AppColorSchemes.light.brightness, Brightness.light);
      },
    );

    test('provides an explicit dark scheme', () {
      expect(AppColorSchemes.dark.brightness, Brightness.dark);
      expect(AppColorSchemes.dark.primary, const Color(0xFFA9C8EE));
      expect(AppColorSchemes.dark.surface, const Color(0xFF0E1318));
    });
  });

  group('AppTheme', () {
    test('light theme is Material 3 with the Exo 2 typography', () {
      final theme = AppTheme.light();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme, AppColorSchemes.light);
      expect(theme.textTheme.bodyLarge?.fontFamily, AppTypography.fontFamily);
    });

    test('dark theme carries the dark scheme and extensions', () {
      final theme = AppTheme.dark();

      expect(theme.colorScheme, AppColorSchemes.dark);
      expect(theme.extension<BallColors>(), BallColors.dark);
      expect(theme.extension<StatusColors>(), StatusColors.dark);
      expect(theme.extension<BrandColors>(), BrandColors.dark);
    });

    test('light theme carries the light extensions', () {
      final theme = AppTheme.light();

      expect(theme.extension<BallColors>(), BallColors.light);
      expect(theme.extension<StatusColors>(), StatusColors.light);
      expect(theme.extension<BrandColors>(), BrandColors.light);
    });

    test('the progress track is the cloth blue container, never red', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final track = theme.progressIndicatorTheme.linearTrackColor!;

        expect(track, theme.colorScheme.secondaryContainer);
        expect(track.b, greaterThan(track.r));
      }
    });

    test('density is the only knob that changes between audiences', () {
      final compact = AppTheme.light(density: VisualDensity.compact);

      expect(compact.visualDensity, VisualDensity.compact);
      expect(AppTheme.light().visualDensity, VisualDensity.standard);
      expect(compact.colorScheme, AppTheme.light().colorScheme);
    });

    test('accepts a font family (package font when used as dependency)', () {
      final theme = AppTheme.light(fontFamily: AppTypography.packageFontFamily);

      expect(
        theme.textTheme.titleLarge?.fontFamily,
        'packages/billard_cfa/Exo2',
      );
    });

    test('touch targets stay at least 48 dp', () {
      final theme = AppTheme.light();

      expect(AppSpacing.minTouchTarget, 48);
      expect(
        theme.filledButtonTheme.style?.minimumSize?.resolve({}),
        const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
      );
    });
  });

  group('AppSpacing and AppRadii', () {
    test('spacing scale has the documented values', () {
      const scale = [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ];

      expect(scale, [4, 8, 16, 24, 32]);
    });

    test('radii are the documented positive values', () {
      expect(AppRadii.small, 8);
      expect(AppRadii.medium, 12);
      expect(AppRadii.large, 16);
    });

    test('radius shortcuts use the matching value', () {
      expect(AppRadii.smallRadius, BorderRadius.circular(AppRadii.small));
      expect(AppRadii.mediumRadius, BorderRadius.circular(AppRadii.medium));
      expect(AppRadii.largeRadius, BorderRadius.circular(AppRadii.large));
    });
  });

  group('AppTypography', () {
    test('every style has the documented size and line height', () {
      final textTheme = AppTypography.textTheme(AppTypography.fontFamily);
      final expected = <TextStyle?, (double, double)>{
        textTheme.displaySmall: (36, 44),
        textTheme.headlineMedium: (28, 36),
        textTheme.titleLarge: (22, 28),
        textTheme.titleMedium: (16, 24),
        textTheme.bodyLarge: (16, 24),
        textTheme.bodyMedium: (14, 20),
        textTheme.labelLarge: (14, 20),
        textTheme.labelSmall: (12, 16),
      };

      for (final entry in expected.entries) {
        final (size, lineHeight) = entry.value;
        expect(entry.key?.fontSize, size);
        expect(entry.key?.height, closeTo(lineHeight / size, 0.0001));
      }
    });

    test('never goes below 12 px and body text is at least 14', () {
      final textTheme = AppTypography.textTheme(AppTypography.fontFamily);
      final sizes = [
        for (final style in [
          textTheme.displaySmall,
          textTheme.headlineMedium,
          textTheme.titleLarge,
          textTheme.titleMedium,
          textTheme.bodyLarge,
          textTheme.bodyMedium,
          textTheme.labelLarge,
          textTheme.labelSmall,
        ])
          style!.fontSize!,
      ];

      expect(sizes.reduce((a, b) => a < b ? a : b), 12);
      expect(textTheme.bodyLarge?.fontSize, 16);
      expect(textTheme.bodyMedium?.fontSize, 14);
      expect(textTheme.titleLarge?.fontSize, 22);
      expect(textTheme.titleLarge?.height, closeTo(28 / 22, 0.001));
      expect(textTheme.titleLarge?.fontVariations, const [
        FontVariation.weight(600),
      ]);
      expect(textTheme.bodyLarge?.fontWeight, FontWeight.w400);
    });
  });

  group('BallColors', () {
    test('equality takes every colour into account', () {
      const other = Color(0xFF000001);
      final variants = [
        BallColors.light.copyWith(red: other),
        BallColors.light.copyWith(onRed: other),
        BallColors.light.copyWith(yellow: other),
        BallColors.light.copyWith(onYellow: other),
        BallColors.light.copyWith(black: other),
        BallColors.light.copyWith(onBlack: other),
        BallColors.light.copyWith(white: other),
        BallColors.light.copyWith(onWhite: other),
        BallColors.light.copyWith(cloth: other),
        BallColors.light.copyWith(onCloth: other),
      ];

      for (final variant in variants) {
        expect(variant, isNot(BallColors.light));
      }
      expect(BallColors.light.copyWith(), BallColors.light);
      expect(BallColors.light.copyWith().hashCode, BallColors.light.hashCode);
    });

    test('copyWith keeps the untouched colours', () {
      const other = Color(0xFF000001);
      final copy = BallColors.light.copyWith(
        onRed: other,
        onYellow: other,
        black: other,
        onBlack: other,
        white: other,
        onWhite: other,
        onCloth: other,
      );

      expect(copy.red, BallColors.light.red);
      expect(copy.onRed, other);
      expect(copy.yellow, BallColors.light.yellow);
      expect(copy.onYellow, other);
      expect(copy.black, other);
      expect(copy.onBlack, other);
      expect(copy.white, other);
      expect(copy.onWhite, other);
      expect(copy.cloth, BallColors.light.cloth);
      expect(copy.onCloth, other);
    });

    test('lerp mixes every colour halfway', () {
      final mid = BallColors.light.lerp(BallColors.dark, 0.5);

      expect(
        mid.cloth,
        Color.lerp(BallColors.light.cloth, BallColors.dark.cloth, 0.5),
      );
      expect(
        mid.onCloth,
        Color.lerp(BallColors.light.onCloth, BallColors.dark.onCloth, 0.5),
      );
      expect(
        mid.onWhite,
        Color.lerp(BallColors.light.onWhite, BallColors.dark.onWhite, 0.5),
      );
    });
    test('copyWith overrides only the given color', () {
      final copy = BallColors.light.copyWith(red: const Color(0xFF000001));

      expect(copy.red, const Color(0xFF000001));
      expect(copy.yellow, BallColors.light.yellow);
      expect(copy.cloth, BallColors.light.cloth);
    });

    test('lerp interpolates between light and dark', () {
      final start = BallColors.light.lerp(BallColors.dark, 0);
      final end = BallColors.light.lerp(BallColors.dark, 1);

      expect(start, BallColors.light);
      expect(end, BallColors.dark);
    });

    test('lerp with another extension type returns this', () {
      expect(BallColors.light.lerp(null, 0.5), BallColors.light);
    });
  });

  group('StatusColors', () {
    test('equality takes every colour into account', () {
      const other = Color(0xFF000001);

      expect(
        StatusColors.light.copyWith(success: other),
        isNot(StatusColors.light),
      );
      expect(
        StatusColors.light.copyWith(onSuccess: other),
        isNot(StatusColors.light),
      );
      expect(
        StatusColors.light.copyWith(attention: other),
        isNot(StatusColors.light),
      );
      expect(
        StatusColors.light.copyWith(onAttention: other),
        isNot(StatusColors.light),
      );
      expect(StatusColors.light.copyWith(), StatusColors.light);
      expect(
        StatusColors.light.copyWith().hashCode,
        StatusColors.light.hashCode,
      );
    });

    test('lerp mixes every colour halfway', () {
      final mid = StatusColors.light.lerp(StatusColors.dark, 0.5);

      expect(
        mid.onSuccess,
        Color.lerp(
          StatusColors.light.onSuccess,
          StatusColors.dark.onSuccess,
          0.5,
        ),
      );
      expect(
        mid.onAttention,
        Color.lerp(
          StatusColors.light.onAttention,
          StatusColors.dark.onAttention,
          0.5,
        ),
      );
    });

    test('copyWith keeps the untouched colours', () {
      const other = Color(0xFF000001);
      final copy = StatusColors.light.copyWith(
        onSuccess: other,
        onAttention: other,
      );

      expect(copy.success, StatusColors.light.success);
      expect(copy.onSuccess, other);
      expect(copy.attention, StatusColors.light.attention);
      expect(copy.onAttention, other);
    });
    test('copyWith overrides only the given color', () {
      final copy = StatusColors.light.copyWith(
        success: const Color(0xFF000001),
      );

      expect(copy.success, const Color(0xFF000001));
      expect(copy.attention, StatusColors.light.attention);
    });

    test('hash code combines the four colours in declaration order', () {
      const a = Color(0xFF000001);
      const b = Color(0xFF000002);
      const c = Color(0xFF000003);
      const d = Color(0xFF000004);
      const colors = StatusColors(
        success: a,
        onSuccess: b,
        attention: c,
        onAttention: d,
      );

      expect(colors.hashCode, Object.hash(a, b, c, d));
    });

    test('lerp interpolates between light and dark', () {
      expect(StatusColors.light.lerp(StatusColors.dark, 0), StatusColors.light);
      expect(StatusColors.light.lerp(StatusColors.dark, 1), StatusColors.dark);
      expect(StatusColors.light.lerp(null, 0.5), StatusColors.light);
    });
  });
}
