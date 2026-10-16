import 'package:billard_cfa/features/suggest_session/domain/sheet_suggestion.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Où en est la planification de la séance suivante.
enum NextSheetPlanning {
  /// Rien n'est planifié : « Planifier » est proposé.
  idle,

  /// Planification en cours : le bouton est inactif.
  planning,

  /// Planifiée à l'instant.
  planned,

  /// Une séance du groupe pour cette fiche existe déjà à cette date.
  already,
}

/// La séance suivante du catalogue proposée au groupe : fiche, partie, raison,
/// date proposée, « Planifier » et « Modifier la date ».
///
/// Sans fiche pour la notion : repli explicite vers le planificateur, jamais de
/// séance inventée. Un refus de planification est une alerte d'attention (pas
/// de rouge d'état) avec le lien vers le planificateur.
class NextSheetCard extends StatelessWidget {
  const NextSheetCard({
    required this.sheet,
    required this.date,
    required this.planning,
    required this.onPlan,
    required this.onChangeDate,
    required this.onOpenPlanner,
    required this.onOpenPlanned,
    this.failureMessage,
    super.key,
  });

  /// La séance proposée ; `null` pour une notion sans séance du catalogue.
  final SheetSuggestion? sheet;

  /// Date proposée (ou date de la séance planifiée).
  final DateTime date;
  final NextSheetPlanning planning;

  /// Motif du dernier refus de planification.
  final String? failureMessage;

  final VoidCallback onPlan;
  final VoidCallback onChangeDate;
  final VoidCallback onOpenPlanner;
  final VoidCallback onOpenPlanned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    final suggestion = sheet;
    if (suggestion == null) {
      return SectionCard(
        title: l10n.reviewNextTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reviewNextNone),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: onOpenPlanner,
              child: Text(l10n.reviewOpenPlanner),
            ),
          ],
        ),
      );
    }
    final option = suggestion.option;
    final reason = switch (suggestion.kind) {
      SheetSuggestionKind.nextPending => l10n.suggestSheetNextPending,
      SheetSuggestionKind.coversHead => l10n.suggestSheetCoversHead,
      SheetSuggestionKind.repeat => l10n.suggestSheetRepeat(
        dates.formatMediumDate(suggestion.lastGivenOn ?? date),
      ),
    };
    final formatted = dates.formatMediumDate(date);
    final dateLine = switch (planning) {
      NextSheetPlanning.planned => l10n.reviewPlannedFor(formatted),
      NextSheetPlanning.already => l10n.reviewAlreadyPlanned(formatted),
      _ => l10n.reviewProposedFor(formatted),
    };
    final isPlanned =
        planning == NextSheetPlanning.planned ||
        planning == NextSheetPlanning.already;
    final failure = failureMessage;
    return SectionCard(
      title: l10n.reviewNextTitle,
      emphasis: SectionEmphasis.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(option.title, style: theme.textTheme.titleMedium),
          Text(l10n.sheetPartLabel(option.part, option.partCount)),
          Text(reason, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(dateLine, style: theme.textTheme.bodyLarge),
          if (failure != null && !isPlanned) ...[
            const SizedBox(height: AppSpacing.sm),
            AppAlert(level: AlertLevel.attention, message: failure),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (isPlanned)
                OutlinedButton(
                  onPressed: onOpenPlanned,
                  child: Text(l10n.reviewSeeInPlanned),
                )
              else ...[
                FilledButton(
                  onPressed: planning == NextSheetPlanning.planning
                      ? null
                      : onPlan,
                  child: Text(
                    planning == NextSheetPlanning.planning
                        ? l10n.reviewPlanning
                        : l10n.reviewPlan,
                  ),
                ),
                OutlinedButton(
                  onPressed: onChangeDate,
                  child: Text(l10n.plannerChangeDate),
                ),
                if (failure != null)
                  TextButton(
                    onPressed: onOpenPlanner,
                    child: Text(l10n.reviewOpenPlanner),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
