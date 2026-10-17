import 'package:billard_cfa/features/export_sheet/presentation/bloc/export_sheet_cubit.dart';
import 'package:billard_cfa/features/export_sheet/presentation/ui/print_preview_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Le contenu de l'écran « Export PDF » : choix du document, du public, du
/// groupe (fiches résultats), aperçu page à page, puis Enregistrer et
/// Imprimer. L'écran ne contient aucune donnée d'élève ; seuls les prénoms du
/// groupe choisi, demandés avec un avertissement, partent dans le PDF.
class ExportView extends StatelessWidget {
  const ExportView({
    required this.state,
    required this.onKindChanged,
    required this.onAudienceChanged,
    required this.onGroupChanged,
    required this.onNamesChanged,
    required this.onPageChanged,
    required this.onSave,
    required this.onPrint,
    super.key,
  });

  final ExportSheetState state;
  final ValueChanged<ExportKind> onKindChanged;
  final ValueChanged<Audience> onAudienceChanged;
  final ValueChanged<GroupId?> onGroupChanged;
  final ValueChanged<bool> onNamesChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onSave;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final results = state.kind == ExportKind.results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: l10n.exportKindSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (kind, label) in [
                    (ExportKind.animator, l10n.exportKindAnimator),
                    (ExportKind.results, l10n.exportKindResults),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: state.kind == kind,
                      onSelected: (_) => onKindChanged(kind),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                results ? l10n.exportResultsHint : l10n.exportAnimatorHint,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: l10n.exportAudienceSection,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in Audience.values)
                ChoiceChip(
                  label: Text(
                    l10n.sheetAudienceOption(
                      option.label(l10n),
                      option.sessionDuration.inMinutes,
                    ),
                  ),
                  selected: option == state.audience,
                  onSelected: (_) => onAudienceChanged(option),
                ),
            ],
          ),
        ),
        if (results) ...[
          const SizedBox(height: AppSpacing.md),
          _NamesCard(
            state: state,
            onGroupChanged: onGroupChanged,
            onNamesChanged: onNamesChanged,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _PreviewCard(state: state, onPageChanged: onPageChanged),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: state.exported == null ? null : onSave,
              icon: const Icon(Icons.save_alt),
              label: Text(l10n.exportSave),
            ),
            if (state.canPrint)
              OutlinedButton.icon(
                onPressed: state.exported == null ? null : onPrint,
                icon: const Icon(Icons.print_outlined),
                label: Text(l10n.exportPrint),
              ),
          ],
        ),
        _Outcome(outcome: state.outcome),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.exportAccessibilityNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Groupe et prénoms (fiches résultats) : le groupe se choisit, les prénoms
/// se demandent à part, avec un avertissement.
class _NamesCard extends StatelessWidget {
  const _NamesCard({
    required this.state,
    required this.onGroupChanged,
    required this.onNamesChanged,
  });

  final ExportSheetState state;
  final ValueChanged<GroupId?> onGroupChanged;
  final ValueChanged<bool> onNamesChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: l10n.exportNamesSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.groupsFailure != null) ...[
            AppAlert(
              level: AlertLevel.attention,
              message: l10n.exportGroupsFailed,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          DropdownButtonFormField<GroupId?>(
            key: const ValueKey('export-group'),
            initialValue: state.groupId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.exportGroupLabel),
            items: [
              DropdownMenuItem<GroupId?>(child: Text(l10n.exportGroupNone)),
              for (final group in state.groups)
                DropdownMenuItem<GroupId?>(
                  value: group.id,
                  child: Text(group.name),
                ),
            ],
            onChanged: onGroupChanged,
          ),
          SwitchListTile(
            key: const ValueKey('export-names'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.exportNamesSwitch),
            value: state.includeNames,
            onChanged: state.groupId == null ? null : onNamesChanged,
          ),
          if (state.includeNames) ...[
            const SizedBox(height: AppSpacing.sm),
            AppAlert(
              level: AlertLevel.attention,
              message: l10n.exportNamesWarning,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.state, required this.onPageChanged});

  final ExportSheetState state;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exported = state.exported;
    return SectionCard(
      title: l10n.exportPreviewTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.preparing) ...[
            LinearProgressIndicator(semanticsLabel: l10n.exportPreparing),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.exportPreparing),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (exported != null) ...[
            PrintPreviewView(document: exported.document, page: state.page),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: l10n.exportPrevious,
                  onPressed: state.page > 0
                      ? () => onPageChanged(state.page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(l10n.exportPageOf(state.page + 1, state.pageCount)),
                IconButton(
                  tooltip: l10n.exportNext,
                  onPressed: state.page < state.pageCount - 1
                      ? () => onPageChanged(state.page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Résultat de la dernière demande : toujours dit en texte.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.outcome});

  final ExportOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, text) = switch (outcome) {
      ExportOutcome.none => (null, null),
      ExportOutcome.saved => (Icons.check_circle_outline, l10n.exportSaved),
      ExportOutcome.cancelled => (Icons.info_outline, l10n.exportCancelled),
      ExportOutcome.saveFailed => (Icons.error_outline, l10n.exportSaveFailed),
      ExportOutcome.printed => (Icons.print_outlined, l10n.exportPrinted),
      ExportOutcome.printFailed => (
        Icons.error_outline,
        l10n.exportPrintFailed,
      ),
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
