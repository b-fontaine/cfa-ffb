import 'package:flutter/material.dart';

/// Ressources de marque du thème : le logo de la FFB.
///
/// [logo] est `null` tant que l'autorisation écrite de la FFB n'existe pas
/// (ADR 0010, décision Q2) : aucun composant n'affiche alors de logo. Un seul
/// endroit à rallumer : `AppTheme.light/dark(showFfbLogo: true)`.
///
/// Passer par le thème permet à un hôte (Widgetbook) de résoudre l'asset sous
/// `packages/billard_cfa/` sans que les widgets connaissent le package, comme
/// pour la police (`AppTypography.packageFontFamily`).
@immutable
class BrandAssets extends ThemeExtension<BrandAssets> {
  const BrandAssets({this.logo});

  /// Ressources de l'application ; [package] sert aux hôtes qui la consomment
  /// comme dépendance.
  factory BrandAssets.fromPackage([String? package]) =>
      BrandAssets(logo: AssetImage(logoAsset, package: package));

  /// Chemin de l'asset ; déclaré dans `pubspec.yaml` (`assets/images/`).
  static const logoAsset = 'assets/images/ffb-logo.png';

  /// Rapport largeur / hauteur du logo (PNG 480 × 300, vérifié par test).
  static const double logoAspectRatio = 480 / 300;

  /// Logo à afficher, ou `null` : pas de ressource de marque.
  final AssetImage? logo;

  @override
  BrandAssets copyWith({AssetImage? logo}) =>
      BrandAssets(logo: logo ?? this.logo);

  @override
  BrandAssets lerp(ThemeExtension<BrandAssets>? other, double t) =>
      other is BrandAssets && t >= 0.5 ? other : this;

  @override
  bool operator ==(Object other) => other is BrandAssets && other.logo == logo;

  @override
  int get hashCode => logo.hashCode;
}
