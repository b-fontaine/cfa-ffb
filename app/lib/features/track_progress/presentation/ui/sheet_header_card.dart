import 'dart:math' as math;

import 'package:billard_cfa/entities/exercise_result/domain/exercise_result.dart'
    as result;
import 'package:billard_cfa/features/track_progress/domain/sheet_header.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/pass_dots.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// En-tête de la fiche d'un élève : où il en est (techniques terminées,
/// exercices validés, jamais un « 0 sur 70 »), l'exercice en cours avec ses
/// réussites, le prochain, puis l'alerte la plus grave et les alertes déjà
/// vues.
///
/// [titleOf] donne le titre localisé d'un exercice. [onAcknowledge] (bouton
/// « Vu ») et [onRestore] (« Rétablir ») sont fournis par la page, qui compose
/// la fonctionnalité d'acquittement (ADR 0013) ; sans eux, aucune action.
class SheetHeaderCard extends StatelessWidget {
  const SheetHeaderCard({
    required this.header,
    required this.titleOf,
    this.onAcknowledge,
    this.onRestore,
    super.key,
  });

  final SheetHeader header;
  final String Function(ExerciseRef exercise) titleOf;
  final ValueChanged<ExerciseRef>? onAcknowledge;
  final ValueChanged<ExerciseRef>? onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current = header.current;
    final next = header.next;
    return SectionCard(
      title: l10n.sheetOverview,
      emphasis: SectionEmphasis.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header.toStart)
            Text(l10n.sheetPathToStart, style: theme.textTheme.titleMedium)
          else ...[
            Text(
              l10n.sheetHeaderTechniques(
                header.finishedTechniques,
                header.techniqueCount,
              ),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              l10n.sheetHeaderExercises(header.validatedExercises),
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (current == null)
            Text(l10n.sheetNextNone, style: theme.textTheme.bodyLarge)
          else ...[
            _Line(
              label: header.toStart
                  ? l10n.sheetCurrentToStart
                  : l10n.sheetCurrent,
              title: titleOf(current),
              trailing: PassDots(
                value: List.filled(
                  math.min(header.currentPassed, header.passesRequired),
                  true,
                ),
                total: header.passesRequired,
                readOnly: true,
              ),
            ),
            if (next != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _Line(label: l10n.sheetNext, title: titleOf(next)),
            ],
          ],
          ..._alert(context, l10n),
          for (final seen in header.acknowledged) ..._seen(context, l10n, seen),
        ],
      ),
    );
  }

  List<Widget> _alert(BuildContext context, AppLocalizations l10n) {
    final alert = header.alert;
    if (alert == null) return const [];
    final theme = Theme.of(context);
    final onAcknowledge = this.onAcknowledge;
    final title = titleOf(alert.exercise);
    return [
      const SizedBox(height: AppSpacing.md),
      AppAlert(
        level: alert.alert == result.AlertLevel.persistent
            ? AlertLevel.persistent
            : AlertLevel.attention,
        message: l10n.sheetAlertConsecutive(title, alert.consecutiveFailures),
      ),
      if (alert.otherAlerts > 0 || onAcknowledge != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: alert.otherAlerts > 0
                    ? Text(
                        l10n.sheetAlertMore(alert.otherAlerts),
                        style: theme.textTheme.bodyMedium,
                      )
                    : const SizedBox.shrink(),
              ),
              if (onAcknowledge != null)
                Semantics(
                  button: true,
                  label: l10n.sheetAlertSeenFor(title),
                  excludeSemantics: true,
                  child: OutlinedButton(
                    onPressed: () => onAcknowledge(alert.exercise),
                    child: Text(l10n.sheetAlertSeen),
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _seen(
    BuildContext context,
    AppLocalizations l10n,
    AcknowledgedAlert seen,
  ) {
    final theme = Theme.of(context);
    final onRestore = this.onRestore;
    final title = titleOf(seen.exercise);
    final date = MaterialLocalizations.of(context).formatMediumDate(seen.date);
    return [
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.sheetAlertSeenOn(date, title),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (onRestore != null)
            Semantics(
              button: true,
              label: l10n.sheetAlertRestoreFor(title),
              excludeSemantics: true,
              child: TextButton(
                onPressed: () => onRestore(seen.exercise),
                child: Text(l10n.sheetAlertRestore),
              ),
            ),
        ],
      ),
    ];
  }
}

/// Une ligne « libellé, titre de l'exercice » avec, au besoin, ses pastilles.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.title, this.trailing});

  final String label;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        Text(title, style: theme.textTheme.bodyLarge),
        ?trailing,
      ],
    );
  }
}
