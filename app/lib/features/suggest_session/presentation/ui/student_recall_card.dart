import 'package:billard_cfa/features/suggest_session/domain/recall_advice.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:flutter/material.dart';

/// Notion à rappeler à un élève, avec la raison (jamais bloquant).
class StudentRecallCard extends StatelessWidget {
  const StudentRecallCard({required this.advice, super.key});

  /// `null` : rien à rappeler pour le moment.
  final RecallAdvice? advice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final advice = this.advice;
    return SectionCard(
      title: l10n.sheetRecall,
      child: advice == null
          ? Text(l10n.sheetRecallNone, style: theme.textTheme.bodyLarge)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sheetRecallValue(
                    advice.blockTitle,
                    advice.exercise.number,
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(switch (advice.reason) {
                  RecallReason.groupFailure ||
                  RecallReason.lastFailed => l10n.sheetRecallReasonLastFailed,
                  RecallReason.activeAlert => l10n.sheetRecallReasonActiveAlert,
                  RecallReason.stale => l10n.sheetRecallReasonStale,
                }, style: theme.textTheme.bodyMedium),
              ],
            ),
    );
  }
}
