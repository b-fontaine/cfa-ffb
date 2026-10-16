import 'package:billard_cfa/features/track_progress/domain/week_summary.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:flutter/material.dart';

/// Le travail des 7 derniers jours : passages saisis, exercices validés,
/// séances données.
class WeekSummaryCard extends StatelessWidget {
  const WeekSummaryCard({required this.summary, super.key});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SectionCard(
      title: l10n.homeWeekTitle,
      child: summary.passes == 0 && summary.sessions == 0
          ? Text(l10n.homeWeekNone)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeWeekPasses(summary.passes),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  l10n.homeWeekValidations(summary.validations),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  l10n.homeWeekSessions(summary.sessions),
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
    );
  }
}
