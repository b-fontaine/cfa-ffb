import 'package:flutter/widgets.dart';

/// Échelle d'espacements (dp) partagée par les publics enfants et adultes.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Taille minimale d'une cible tactile (Material, WCAG 2.5.8).
  static const double minTouchTarget = 48;
}

/// Rayons de coins : sobres, pas de pilules hors puces de filtre.
abstract final class AppRadii {
  /// Champs et puces.
  static const double small = 8;

  /// Cartes et boutons.
  static const double medium = 12;

  /// Dialogues et feuilles basses.
  static const double large = 16;

  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );
  static const BorderRadius mediumRadius = BorderRadius.all(
    Radius.circular(medium),
  );
  static const BorderRadius largeRadius = BorderRadius.all(
    Radius.circular(large),
  );
}
