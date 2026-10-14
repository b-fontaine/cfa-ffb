import 'dart:async';

import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/features/record_results/presentation/bloc/record_results_bloc.dart';
import 'package:billard_cfa/features/record_results/presentation/ui/attempt_edit_dialog.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/exercise_title.dart' as title;
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Passages déjà saisis dans la séance, chacun avec sa correction et sa
/// suppression (ADR 0006) ; dernier changement et dernier refus affichés.
class AttemptHistory extends StatelessWidget {
  const AttemptHistory({required this.state, super.key});

  final RecordResultsState state;

  String _exerciseTitle(AppLocalizations l10n, ExerciseAttempt attempt) {
    final catalogue = state.overview!.catalogue;
    final block = catalogue.blockById(attempt.exercise.blockId);
    return title.exerciseTitle(
      l10n,
      blockTitle: block?.title ?? attempt.exercise.blockId,
      number: attempt.exercise.number,
      proposal: block?.isProposal ?? false,
    );
  }

  String _studentName(ExerciseAttempt attempt) =>
      state.overview!.students
          .where((s) => s.id == attempt.studentId)
          .map((s) => s.firstName)
          .firstOrNull ??
      '';

  bool _isInCatalogue(ExerciseAttempt attempt) =>
      state.overview!.catalogue.exercise(attempt.exercise) != null;

  Future<void> _edit(BuildContext context, ExerciseAttempt attempt) async {
    final bloc = context.read<RecordResultsBloc>();
    final l10n = AppLocalizations.of(context);
    final rate = state.overview!.catalogue.exercise(attempt.exercise)?.rate;
    if (rate == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AttemptEditDialog(
        studentName: _studentName(attempt),
        exerciseTitle: _exerciseTitle(l10n, attempt),
        attempt: attempt,
        rate: rate,
        onSave: (potted, total) {
          Navigator.of(dialogContext).pop();
          bloc.add(
            RecordResultsEvent.attemptCorrected(
              attemptId: attempt.id,
              potted: potted,
              total: total,
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, ExerciseAttempt attempt) async {
    final bloc = context.read<RecordResultsBloc>();
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.recordDeleteAttemptTitle,
      message: l10n.recordDeleteAttemptBody(
        _studentName(attempt),
        _exerciseTitle(l10n, attempt),
        attempt.potted,
        attempt.total,
      ),
    );
    if (confirmed) {
      bloc.add(RecordResultsEvent.attemptDeleted(attemptId: attempt.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final attempts = state.overview!.attempts;
    final change = state.attemptChange;
    final refused = state.attemptRefused;
    return SectionCard(
      title: l10n.recordHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attempts.isEmpty)
            Text(l10n.recordHistoryEmpty)
          else
            for (final attempt in attempts)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.recordHistoryRow(
                        _studentName(attempt),
                        _exerciseTitle(l10n, attempt),
                        attempt.potted,
                        attempt.total,
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.recordEditAttempt(
                      _studentName(attempt),
                      attempt.potted,
                      attempt.total,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    // Sans fiche au catalogue, pas de borne de tentatives :
                    // la correction est impossible, le bouton le dit.
                    onPressed: _isInCatalogue(attempt)
                        ? () => unawaited(_edit(context, attempt))
                        : null,
                  ),
                  IconButton(
                    tooltip: l10n.recordDeleteAttempt(
                      _studentName(attempt),
                      attempt.potted,
                      attempt.total,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => unawaited(_delete(context, attempt)),
                  ),
                ],
              ),
          if (change != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(switch (change) {
              AttemptCorrected(:final attempt) => l10n.recordAttemptCorrected(
                attempt.potted,
                attempt.total,
              ),
              AttemptDeleted() => l10n.recordAttemptDeleted,
            }, style: theme.textTheme.bodyLarge),
          ],
          if (refused != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              failureMessage(l10n, refused),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
