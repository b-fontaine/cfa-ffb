import 'package:flutter/material.dart';

/// Accent de marque : le rouge FFB, hors des rôles Material (ADR 0010).
///
/// Les états (sélection, puces, pistes) restent bleu-tapis (`secondary`) ; le
/// rouge n'apparaît que par un composant du design system : titre de
/// l'application, ligne d'objectif des courbes, badge « Enfants ». Valeurs
/// **proposées**, vérifiées par le test de contraste.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
  });

  static const light = BrandColors(
    accent: Color(0xFFB80D1A),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFDDAD7),
    onAccentContainer: Color(0xFF5C0008),
  );

  static const dark = BrandColors(
    accent: Color(0xFFFFB3AD),
    onAccent: Color(0xFF5C0008),
    accentContainer: Color(0xFF8C0012),
    onAccentContainer: Color(0xFFFFDAD6),
  );

  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  @override
  BrandColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
  }) => BrandColors(
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentContainer: accentContainer ?? this.accentContainer,
    onAccentContainer: onAccentContainer ?? this.onAccentContainer,
  );

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      onAccentContainer: Color.lerp(
        onAccentContainer,
        other.onAccentContainer,
        t,
      )!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BrandColors &&
      other.accent == accent &&
      other.onAccent == onAccent &&
      other.accentContainer == accentContainer &&
      other.onAccentContainer == onAccentContainer;

  @override
  int get hashCode =>
      Object.hash(accent, onAccent, accentContainer, onAccentContainer);
}
