import 'package:freezed_annotation/freezed_annotation.dart';

/// Dosage de la puissance : le rapport entre l'**amplitude** (le recul de la
/// main jusqu'à la fin de la pénétration) et la **vitesse** du coup de queue.
///
/// Source `[S]` : fiche technique n° 2 (`02-techniques/02-puissance.md`) : « la
/// puissance dépend de deux critères, la vitesse et l'amplitude » ; peu
/// d'amplitude et peu de vitesse = doucement, grande amplitude et grande
/// vitesse = puissant. Les valeurs relatives et les seuils des zones sont des
/// propositions `[Prop]`. Dart pur.
enum AmplitudeLevel {
  /// Recul court.
  short(0.3),

  /// Recul moyen.
  medium(0.6),

  /// Recul long.
  long(1);

  AmplitudeLevel(this.value);

  /// Valeur relative `[Prop]`, de 0 à 1.
  final double value;
}

/// Vitesse du coup de queue.
enum SpeedLevel {
  slow(0.3),
  medium(0.6),
  fast(1);

  SpeedLevel(this.value);

  /// Valeur relative `[Prop]`, de 0 à 1.
  final double value;
}

/// Zone de puissance atteinte : doux, moyen ou puissant.
enum PowerZone { soft, medium, strong }

/// Produit `amplitude × vitesse` en dessous duquel le coup est doux `[Prop]`.
const double powerSoftLimit = 0.2;

/// Produit `amplitude × vitesse` à partir duquel le coup est puissant
/// `[Prop]`.
const double powerStrongLimit = 0.5;

/// Zone du produit [product] (`amplitude × vitesse`, de 0 à 1) : doux sous
/// [powerSoftLimit], puissant à partir de [powerStrongLimit].
PowerZone powerZoneOfProduct(double product) {
  if (product < powerSoftLimit) return PowerZone.soft;
  if (product < powerStrongLimit) return PowerZone.medium;
  return PowerZone.strong;
}

/// Zone atteinte avec une amplitude et une vitesse données.
PowerZone powerZone(AmplitudeLevel amplitude, SpeedLevel speed) =>
    powerZoneOfProduct(amplitude.value * speed.value);

/// Un exemple placé sur le plan amplitude × vitesse.
@immutable
class PowerPoint {
  const PowerPoint({required this.amplitude, required this.speed, this.label});

  final AmplitudeLevel amplitude;
  final SpeedLevel speed;

  /// Texte de repère de la séance (déjà en français), facultatif.
  final String? label;

  /// Zone atteinte par cet exemple.
  PowerZone get zone => powerZone(amplitude, speed);

  @override
  bool operator ==(Object other) =>
      other is PowerPoint &&
      other.amplitude == amplitude &&
      other.speed == speed &&
      other.label == label;

  @override
  int get hashCode => Object.hash(amplitude, speed, label);

  @override
  String toString() => 'PowerPoint($amplitude, $speed, $label)';
}
