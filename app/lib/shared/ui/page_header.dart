import 'package:billard_cfa/shared/ui/ffb_logo.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:billard_cfa/shared/ui/theme/brand_assets.dart';
import 'package:flutter/material.dart';

/// En-tête de page : titre (en-tête sémantique), sous-titre optionnel et logo
/// FFB décoratif à droite du titre.
///
/// Le logo ne prend jamais la place du texte : il n'est affiché (si
/// [showLogo]) que lorsque le titre tient sur une ligne à côté de lui ; le
/// sous-titre garde toute la largeur.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.subtitle,
    this.showLogo = true,
    super.key,
  });

  static const _logoHeight = 32.0;

  final String title;
  final String? subtitle;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    final titleStyle = DefaultTextStyle.of(context).style
        .merge(theme.textTheme.headlineMedium);
    final hasLogo = showLogo && theme.extension<BrandAssets>() != null;
    final heading = Semantics(
      header: true,
      child: Text(title, style: theme.textTheme.headlineMedium),
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasLogo)
          LayoutBuilder(
            builder: (context, constraints) {
              final painter = TextPainter(
                text: TextSpan(text: title, style: titleStyle),
                textDirection: direction,
                textScaler: textScaler,
                locale: Localizations.maybeLocaleOf(context),
              )..layout();
              const logoWidth =
                  _logoHeight * BrandAssets.logoAspectRatio + AppSpacing.md;
              final fits = painter.width + logoWidth <= constraints.maxWidth;
              painter.dispose();
              if (!fits) {
                return heading;
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: AppSpacing.md),
                  const FfbLogo(height: _logoHeight, decorative: true),
                ],
              );
            },
          )
        else
          heading,
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
