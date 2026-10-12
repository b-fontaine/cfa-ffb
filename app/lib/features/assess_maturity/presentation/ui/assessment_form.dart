import 'package:billard_cfa/entities/maturity_assessment/domain/maturity_assessment.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/bloc/assessment_bloc.dart';
import 'package:billard_cfa/features/assess_maturity/presentation/ui/score_selector.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bilan de maturité : trois critères de 1 à 4 et un commentaire facultatif.
/// L'enregistrement est refusé tant que les trois critères ne sont pas notés ;
/// le résultat n'est qu'une aide, exposée avec prudence.
class AssessmentForm extends StatefulWidget {
  const AssessmentForm({
    required this.studentId,
    required this.readinessMinScore,
    super.key,
  });

  final StudentId studentId;

  /// Note minimale de chaque critère pour que l'aide soit favorable.
  final int readinessMinScore;

  @override
  State<AssessmentForm> createState() => _AssessmentFormState();
}

class _AssessmentFormState extends State<AssessmentForm> {
  final _comment = TextEditingController();
  int? _concentration;
  int? _endurance;
  int? _frustration;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _complete =>
      _concentration != null && _endurance != null && _frustration != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<AssessmentBloc, AssessmentState>(
      builder: (context, state) {
        final outcome = state.outcome;
        final failure = state.failure;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.assessScoreMeaning, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            ScoreSelector(
              label: l10n.assessConcentration,
              value: _concentration,
              onChanged: (v) => setState(() => _concentration = v),
            ),
            const SizedBox(height: AppSpacing.md),
            ScoreSelector(
              label: l10n.assessEndurance,
              value: _endurance,
              onChanged: (v) => setState(() => _endurance = v),
            ),
            const SizedBox(height: AppSpacing.md),
            ScoreSelector(
              label: l10n.assessFrustration,
              value: _frustration,
              onChanged: (v) => setState(() => _frustration = v),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _comment,
              maxLength: MaturityAssessment.maxCommentLength,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.assessComment),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _complete && state.status != AssessmentStatus.saving
                  ? () => context.read<AssessmentBloc>().add(
                      AssessmentEvent.submitted(
                        studentId: widget.studentId,
                        concentration: _concentration!,
                        endurance: _endurance!,
                        frustration: _frustration!,
                        comment: _comment.text,
                      ),
                    )
                  : null,
              child: Text(l10n.assessSave),
            ),
            if (failure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                failureMessage(l10n, failure),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (outcome != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.assessSaved, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              StatusBadge(
                tone: outcome.readinessHint
                    ? BadgeTone.success
                    : BadgeTone.neutral,
                label: outcome.readinessHint
                    ? l10n.assessHintReady(widget.readinessMinScore)
                    : l10n.assessHintNotReady(widget.readinessMinScore),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.assessHintDisclaimer,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        );
      },
    );
  }
}
