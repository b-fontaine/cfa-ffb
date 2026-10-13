import 'package:billard_cfa/shared/ui/theme/app_color_schemes.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/app_typography.dart';
import 'package:billard_cfa/shared/ui/theme/ball_colors.dart';
import 'package:billard_cfa/shared/ui/theme/brand_assets.dart';
import 'package:billard_cfa/shared/ui/theme/status_colors.dart';
import 'package:billard_cfa/shared/ui/theme/table_colors.dart';
import 'package:flutter/material.dart';

/// Thèmes clair et sombre de l'application.
///
/// Les publics enfants et adultes partagent les mêmes tokens ; seules la
/// densité (`density`) et l'échelle du texte (réglage système) varient.
abstract final class AppTheme {
  static ThemeData light({
    String fontFamily = AppTypography.fontFamily,
    VisualDensity density = VisualDensity.standard,
    String? assetPackage,
  }) => _build(
    AppColorSchemes.light,
    BallColors.light,
    StatusColors.light,
    TableColors.light,
    fontFamily,
    density,
    BrandAssets.fromPackage(assetPackage),
  );

  static ThemeData dark({
    String fontFamily = AppTypography.fontFamily,
    VisualDensity density = VisualDensity.standard,
    String? assetPackage,
  }) => _build(
    AppColorSchemes.dark,
    BallColors.dark,
    StatusColors.dark,
    TableColors.dark,
    fontFamily,
    density,
    BrandAssets.fromPackage(assetPackage),
  );

  static ThemeData _build(
    ColorScheme scheme,
    BallColors balls,
    StatusColors status,
    TableColors table,
    String fontFamily,
    VisualDensity density,
    BrandAssets brand,
  ) {
    const touchTarget = Size(
      AppSpacing.minTouchTarget,
      AppSpacing.minTouchTarget,
    );
    const shape = RoundedRectangleBorder(borderRadius: AppRadii.mediumRadius);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: fontFamily,
      textTheme: AppTypography.textTheme(fontFamily),
      visualDensity: density,
      extensions: [balls, status, table, brand],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.mediumRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: touchTarget, shape: shape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: touchTarget, shape: shape),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: AppRadii.smallRadius),
      ),
    );
  }
}
