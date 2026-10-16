import 'package:billard_cfa/entities/season/domain/season_archive.dart';
import 'package:billard_cfa/features/track_seasons/domain/closed_season.dart';
import 'package:billard_cfa/features/track_seasons/presentation/bloc/season_archives_cubit.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/archive_figure_table.dart';
import 'package:billard_cfa/shared/ui/audience_badge.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:billard_cfa/shared/ui/error_view.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:billard_cfa/shared/ui/loading_view.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Les saisons closes : une carte par saison, les chiffres par public et le
/// tableau des exercices pratiqués par assez d'élèves. Lecture seule ; aucun
/// prénom n'existe ici.
class SeasonArchiveView extends StatelessWidget {
  const SeasonArchiveView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<SeasonArchivesCubit, SeasonArchivesState>(
      builder: (context, state) {
        switch (state.status) {
          case SeasonArchivesStatus.loading:
            return const SizedBox(height: 200, child: LoadingView());
          case SeasonArchivesStatus.failure:
            return SizedBox(
              height: 240,
              child: ErrorView(
                message: failureMessage(l10n, state.failure!),
                onRetry: () => context.read<SeasonArchivesCubit>().load(),
              ),
            );
          case SeasonArchivesStatus.ready:
            if (state.seasons.isEmpty) {
              return SizedBox(
                height: 320,
                child: EmptyState(
                  message: l10n.seasonsEmpty,
                  icon: Icons.history,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final closed in state.seasons) ...[
                  _SeasonCard(closed: closed),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
        }
      },
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.closed});

  final ClosedSeason closed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    final season = closed.season;
    return SectionCard(
      title: season.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.seasonsPeriod(
              dates.formatMediumDate(season.startDate),
              dates.formatMediumDate(season.endDate),
            ),
          ),
          Text(
            l10n.seasonsClosedOn(dates.formatMediumDate(season.closedOn!)),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (closed.audiences.isEmpty)
            Text(l10n.seasonsNoFigures)
          else
            for (final audience in closed.audiences) ...[
              _AudienceFigures(figures: audience),
              const SizedBox(height: AppSpacing.sm),
            ],
          if (closed.exercises.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                l10n.archiveExercisesTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ArchiveFigureTable(
              rows: [
                for (final line in closed.exercises)
                  (
                    title: line.blockTitle,
                    number: line.exerciseNumber,
                    students: line.studentCount,
                    attempts: line.attemptCount,
                    potted: line.potted,
                    total: line.total,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.archiveExercisesNote(minCohortForFigures),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AudienceFigures extends StatelessWidget {
  const _AudienceFigures({required this.figures});

  final AudienceArchive figures;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AudienceBadge(kind: figures.audience.kind),
        ),
        Text(l10n.archiveSessions(figures.sessionCount)),
        if (figures.studentCount < minCohortForFigures)
          Text(l10n.archiveFiguresWithheld(minCohortForFigures))
        else ...[
          Text(
            l10n.archivePresences(
              figures.presenceCount,
              figures.possiblePresenceCount,
            ),
          ),
          Text(l10n.archiveStudents(figures.studentCount)),
          Text(l10n.archiveAttempts(figures.attemptCount)),
        ],
      ],
    );
  }
}
