import 'package:flutter/material.dart';

/// Échelle typographique Exo 2 (charte FFB, licence OFL, embarquée en assets).
abstract final class AppTypography {
  /// Famille déclarée dans `pubspec.yaml` de l'application.
  static const fontFamily = 'Exo2';

  /// Nom de la famille lorsque l'application est utilisée comme dépendance
  /// (Widgetbook) : Flutter préfixe les polices des paquets.
  static const packageFontFamily = 'packages/billard_cfa/$fontFamily';

  static TextStyle _style(
    String family,
    double size,
    double lineHeight, [
    FontWeight weight = FontWeight.w400,
  ]) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    // Exo 2 est une police variable : l'axe `wght` est fixé explicitement.
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
  );

  static TextTheme textTheme(String family) => TextTheme(
    displaySmall: _style(family, 36, 44, FontWeight.w700),
    headlineMedium: _style(family, 28, 36, FontWeight.w700),
    titleLarge: _style(family, 22, 28, FontWeight.w600),
    titleMedium: _style(family, 16, 24, FontWeight.w600),
    bodyLarge: _style(family, 16, 24),
    bodyMedium: _style(family, 14, 20),
    labelLarge: _style(family, 14, 20, FontWeight.w600),
    labelSmall: _style(family, 12, 16, FontWeight.w600),
  );
}
