import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/theme/brand_assets.dart';
import 'package:flutter/material.dart';

/// Logo de la Fédération française de billard, issu du thème
/// ([BrandAssets]).
///
/// [decorative] le retire de l'arbre sémantique (en-tête répété sur chaque
/// page) ; sinon il porte son libellé localisé. Rien n'est affiché si le thème
/// ne porte pas de logo (`BrandAssets.logo == null`, cas par défaut).
class FfbLogo extends StatelessWidget {
  const FfbLogo({this.height = 48, this.decorative = false, super.key});

  final double height;
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final logo = Theme.of(context).extension<BrandAssets>()?.logo;
    if (logo == null) {
      return const SizedBox.shrink();
    }
    return Image(
      image: logo,
      height: height,
      width: height * BrandAssets.logoAspectRatio,
      fit: BoxFit.contain,
      excludeFromSemantics: decorative,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
      semanticLabel: decorative
          ? null
          : AppLocalizations.of(context).ffbLogoLabel,
    );
  }
}
