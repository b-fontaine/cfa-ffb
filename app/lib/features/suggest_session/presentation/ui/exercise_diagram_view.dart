import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/ball_contact_diagram.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Schéma(s) de table d'un exercice : lecture, pause, rejouer, vitesse, avec
/// la quantité de bille et le chevalet écrits en texte.
///
/// Quand la source répète la fiche (le rejet naturel), chaque schéma est
/// numéroté. Sans schéma, ou si les schémas n'ont pas pu être lus, un message
/// remplace le lecteur : la fiche reste utilisable.
class ExerciseDiagramView extends StatelessWidget {
  const ExerciseDiagramView({required this.sheet, super.key});

  final ExerciseSheet sheet;

  /// Largeur maximale du schéma : lisible en projection sans s'étirer sur une
  /// tablette en paysage (la page défile).
  static const double maxDiagramWidth = 720;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diagrams = sheet.diagrams;
    return SectionCard(
      title: l10n.exerciseDiagramTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sheet.diagramsUnreadable)
            Text(l10n.diagramInvalid)
          else if (diagrams.isEmpty)
            Text(l10n.exerciseDiagramMissing)
          else
            for (var i = 0; i < diagrams.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.lg),
              _DiagramEntry(
                diagram: diagrams[i],
                number: sheet.spec.ref.number,
                sheetTitle: sheet.block.title,
                position: diagrams.length > 1 ? i + 1 : null,
                total: diagrams.length,
              ),
            ],
        ],
      ),
    );
  }
}

class _DiagramEntry extends StatelessWidget {
  const _DiagramEntry({
    required this.diagram,
    required this.number,
    required this.sheetTitle,
    required this.position,
    required this.total,
  });

  final ExerciseDiagram diagram;
  final int number;
  final String sheetTitle;

  /// Rang du schéma quand il y en a plusieurs ; `null` pour un schéma seul.
  final int? position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final contacts = diagram.contacts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (position != null) ...[
          Text(
            l10n.exerciseDiagramNumbered(position!, total),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ExerciseDiagramView.maxDiagramWidth,
            ),
            child: TableDiagramPlayer(
              spec: tableDiagramSpecOf(diagram),
              semanticLabel: l10n.exerciseDiagramSemantics(number, sheetTitle),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(diagram.caption, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          contacts.isEmpty
              ? l10n.exerciseDiagramContactUnspecified
              : l10n.exerciseDiagramContact(
                  contacts
                      .map(
                        (c) => BallContactDiagram.contactLabel(
                          l10n,
                          contactFractionOf(c),
                        ),
                      )
                      .join(l10n.listSeparator),
                ),
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
