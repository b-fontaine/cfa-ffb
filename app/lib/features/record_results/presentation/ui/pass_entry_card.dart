import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Saisie d'un passage d'un élève sur l'exercice courant : billes empochées
/// et tentatives (par défaut celles du catalogue), compteur de passages de la
/// séance, retour immédiat (objectif, validation, alerte).
class PassEntryCard extends StatefulWidget {
  const PassEntryCard({
    required this.studentName,
    required this.spec,
    required this.passesDone,
    required this.maxPasses,
    required this.onSubmit,
    this.feedback,
    this.nextExerciseLabel,
    this.refusedMessage,
    super.key,
  });

  final String studentName;
  final ExerciseSpec spec;
  final int passesDone;
  final int maxPasses;
  final void Function(int potted, int total) onSubmit;

  /// Dernier passage enregistré (retour affiché sous le bouton).
  final RecordedAttempt? feedback;

  /// Titre de l'exercice suivant recommandé ; `null` : niveau terminé.
  final String? nextExerciseLabel;

  /// Message du dernier passage refusé.
  final String? refusedMessage;

  @override
  State<PassEntryCard> createState() => _PassEntryCardState();
}

class _PassEntryCardState extends State<PassEntryCard> {
  late int _potted = 0;
  late int _total = widget.spec.rate.attempts;

  @override
  void didUpdateWidget(PassEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.ref != widget.spec.ref) {
      _potted = 0;
      _total = widget.spec.rate.attempts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = widget.studentName;
    final limitReached = widget.passesDone >= widget.maxPasses;
    final feedback = widget.feedback;
    final refused = widget.refusedMessage;
    return SectionCard(
      title: name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              CounterField(
                label: l10n.recordPotted,
                value: _potted,
                max: _total,
                decreaseTooltip: l10n.recordPottedLess(name),
                increaseTooltip: l10n.recordPottedMore(name),
                onChanged: (value) => setState(() => _potted = value),
              ),
              CounterField(
                label: l10n.recordAttempts,
                value: _total,
                min: widget.spec.rate.attempts,
                max: SuccessRate.maxAttempts,
                decreaseTooltip: l10n.recordAttemptsLess(name),
                increaseTooltip: l10n.recordAttemptsMore(name),
                onChanged: (value) => setState(() {
                  _total = value;
                  if (_potted > _total) _potted = _total;
                }),
              ),
            ],
          ),
          if (_total != widget.spec.rate.attempts) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.recordCustomTotal, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.recordPassesDone(widget.passesDone, widget.maxPasses),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (limitReached)
            StatusBadge(tone: BadgeTone.neutral, label: l10n.recordLimitReached)
          else
            FilledButton(
              onPressed: () => widget.onSubmit(_potted, _total),
              child: Text(l10n.recordSubmit),
            ),
          if (refused != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(refused, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (feedback != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              feedback.passed
                  ? l10n.recordFeedbackReached(
                      feedback.attempt.potted,
                      feedback.attempt.total,
                    )
                  : l10n.recordFeedbackMissed(
                      feedback.attempt.potted,
                      feedback.attempt.total,
                    ),
              style: theme.textTheme.bodyLarge,
            ),
            if (feedback.justValidated) ...[
              const SizedBox(height: AppSpacing.xs),
              StatusBadge(tone: BadgeTone.success, label: l10n.recordValidated),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.nextExerciseLabel == null
                    ? l10n.recordNextNone
                    : l10n.recordNext(widget.nextExerciseLabel!),
              ),
            ],
            if (feedback.result.hasActiveAlert) ...[
              const SizedBox(height: AppSpacing.sm),
              AppAlert(
                level: AlertLevel.attention,
                message: l10n.recordAlert(feedback.result.consecutiveFailures),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
