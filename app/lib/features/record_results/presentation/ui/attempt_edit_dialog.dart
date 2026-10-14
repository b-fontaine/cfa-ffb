import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Correction d'un passage déjà saisi : billes empochées et tentatives (au
/// moins celles de la fiche), préremplies avec les valeurs du passage.
/// [onSave] reçoit les valeurs corrigées ; la boîte se ferme par le parent.
class AttemptEditDialog extends StatefulWidget {
  const AttemptEditDialog({
    required this.studentName,
    required this.exerciseTitle,
    required this.attempt,
    required this.rate,
    required this.onSave,
    super.key,
  });

  final String studentName;
  final String exerciseTitle;
  final ExerciseAttempt attempt;

  /// Taux requis par la fiche : borne basse des tentatives.
  final SuccessRate rate;
  final void Function(int potted, int total) onSave;

  @override
  State<AttemptEditDialog> createState() => _AttemptEditDialogState();
}

class _AttemptEditDialogState extends State<AttemptEditDialog> {
  late int _potted = widget.attempt.potted;
  late int _total = widget.attempt.total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.recordEditAttemptTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recordEditAttemptSubject(
              widget.studentName,
              widget.exerciseTitle,
            ),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              CounterField(
                label: l10n.recordPotted,
                value: _potted,
                max: _total,
                decreaseTooltip: l10n.recordCorrectionPottedLess,
                increaseTooltip: l10n.recordCorrectionPottedMore,
                onChanged: (value) => setState(() => _potted = value),
              ),
              CounterField(
                label: l10n.recordAttempts,
                value: _total,
                min: widget.rate.attempts,
                max: SuccessRate.maxAttempts,
                decreaseTooltip: l10n.recordCorrectionAttemptsLess,
                increaseTooltip: l10n.recordCorrectionAttemptsMore,
                onChanged: (value) => setState(() {
                  _total = value;
                  if (_potted > _total) _potted = _total;
                }),
              ),
            ],
          ),
          if (_total != widget.rate.attempts) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.recordCustomTotal, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => widget.onSave(_potted, _total),
          child: Text(l10n.recordEditAttemptSave),
        ),
      ],
    );
  }
}
