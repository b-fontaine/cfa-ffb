import 'package:billard_cfa/entities/session_sheet/presentation/illustration_mapper.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/ui/presentation_scope.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Une illustration de séance, sa légende et, si l'élément qui la référence
/// est une proposition `[Prop]`, le badge « Proposition » (une illustration
/// prend la provenance de l'élément qui la cite).
///
/// [diagrams] : schémas déjà résolus par identifiant de diagramme (pour les
/// illustrations `diagram_ref`). Sous un `PresentationScope`, la figure est
/// plus large ; la légende reste écrite sous elle.
class SheetIllustrationView extends StatelessWidget {
  const SheetIllustrationView({
    required this.illustration,
    required this.diagrams,
    this.proposal = false,
    this.showCaption = true,
    this.presentationHeight,
    super.key,
  });

  final Illustration illustration;
  final Map<String, TableDiagramSpec> diagrams;

  /// Vrai quand l'élément qui référence l'illustration est un `[Prop]`.
  final bool proposal;

  /// Faux quand la légende est déjà écrite par l'appelant (présentation).
  final bool showCaption;

  /// Hauteur maximale du schéma et de ses commandes en mode présentation,
  /// quand l'appelant la borne pour que figure et légende tiennent à l'écran.
  final double? presentationHeight;

  /// Largeur maximale d'une figure, en dp : lisible sans s'étirer.
  static const double maxWidth = 560;

  /// Largeur maximale en mode présentation.
  static const double presentationMaxWidth = 960;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = PresentationScope.isActive(context)
        ? presentationMaxWidth
        : maxWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: IllustrationMapper.build(
              context,
              illustration,
              diagrams: diagrams,
              diagramMaxHeight: PresentationScope.isActive(context)
                  ? presentationHeight
                  : null,
            ),
          ),
        ),
        if (showCaption) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(illustration.caption, style: theme.textTheme.bodyLarge),
        ],
        if (proposal) ...[
          const SizedBox(height: AppSpacing.sm),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: ProposalBadge(),
          ),
        ],
      ],
    );
  }
}
