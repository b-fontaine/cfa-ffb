import 'dart:async';

import 'package:billard_cfa/features/plan_session/presentation/bloc/upcoming_sessions_cubit.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/upcoming_cards.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/run_key.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_session.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_sessions_cubit.dart';
import 'package:billard_cfa/features/run_sheet/presentation/ui/running_session_card.dart';
import 'package:billard_cfa/features/track_group/presentation/bloc/group_alerts_cubit.dart';
import 'package:billard_cfa/features/track_group/presentation/ui/group_alerts_card.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/watched_students_cubit.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/week_summary_cubit.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/watched_students_card.dart';
import 'package:billard_cfa/features/track_progress/presentation/ui/week_summary_card.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:billard_cfa/shared/ui/cloth_pattern.dart';
import 'package:billard_cfa/shared/ui/confirm_dialog.dart';
import 'package:billard_cfa/shared/ui/responsive_body.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Accueil « Aujourd'hui » : séance en cours à reprendre, prochaine séance
/// (Préparer / Lancer), séances à noter, élèves à surveiller, 7 derniers jours.
///
/// La page compose quatre sections indépendantes (un cubit chacune) : l'échec
/// de l'une propose « Réessayer » sans cacher les autres. Elle ne calcule
/// rien. Les cubits sont fournis par la couche `app`, qui compose aussi le
/// [banner] (rappel de sauvegarde) et les callbacks de navigation.
class HomePage extends StatelessWidget {
  const HomePage({
    required this.today,
    required this.onOpenPlanner,
    required this.onOpenSuggestion,
    required this.onAddStudents,
    required this.onOpenStudents,
    required this.onOpenStudent,
    required this.onOpenGroup,
    required this.onResume,
    required this.onPrepare,
    required this.onLaunch,
    required this.onOpenPlanned,
    required this.onRecord,
    this.banner,
    super.key,
  });

  /// Jour courant (horloge injectée).
  final DateTime Function() today;

  final VoidCallback onOpenPlanner;
  final VoidCallback onOpenSuggestion;
  final VoidCallback onAddStudents;
  final VoidCallback onOpenStudents;
  final ValueChanged<StudentId> onOpenStudent;

  /// Ouvre la grille d'un groupe (alertes de groupe).
  final ValueChanged<GroupId> onOpenGroup;

  /// Rouvre le guide de [RunKey] à l'étape donnée.
  final void Function(RunKey key, int step) onResume;
  final void Function(SheetId sheet, Audience audience) onPrepare;
  final void Function(SheetId sheet, Audience audience, String sessionId)
  onLaunch;
  final VoidCallback onOpenPlanned;
  final void Function(GroupId group, DateTime date, SheetId? sheet) onRecord;

  /// Bandeau facultatif au-dessus du contenu (rappel de sauvegarde, composé
  /// par la couche app).
  final Widget? banner;

  Future<void> _abandon(BuildContext context, RunKey key) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RunningSessionsCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.homeAbandonTitle,
      message: l10n.homeAbandonBody,
    );
    if (confirmed) await cubit.abandon(key);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final date = MaterialLocalizations.of(context).formatMediumDate(today());
    final header = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ClipRRect(
        borderRadius: AppRadii.mediumRadius,
        child: Stack(
          children: [
            const Positioned.fill(child: ClothPattern()),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  const ExcludeSemantics(
                    child: BilliardBall(
                      kind: BallKind.black,
                      diameter: 40,
                      label: '8',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.homeHeading(date),
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final cards = _Cards(
      onOpenSuggestion: onOpenSuggestion,
      onAddStudents: onAddStudents,
      onResume: onResume,
      onPrepare: onPrepare,
      onLaunch: onLaunch,
      onOpenPlanned: onOpenPlanned,
      onRecord: onRecord,
      onAbandon: (key) => unawaited(_abandon(context, key)),
    );
    final follow = _Follow(
      onOpenStudent: onOpenStudent,
      onOpenStudents: onOpenStudents,
      onOpenGroup: onOpenGroup,
    );
    final plan = FilledButton(
      onPressed: onOpenPlanner,
      child: Text(l10n.homeOpenPlanner),
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            return ResponsiveBody(
              maxWidth: wide ? 1100 : 720,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?banner,
                    header,
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: cards),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: follow),
                        ],
                      )
                    else ...[
                      cards,
                      follow,
                    ],
                    const SizedBox(height: AppSpacing.md),
                    plan,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// « En cours », « Prochaine » et « À noter ».
class _Cards extends StatelessWidget {
  const _Cards({
    required this.onOpenSuggestion,
    required this.onAddStudents,
    required this.onResume,
    required this.onPrepare,
    required this.onLaunch,
    required this.onOpenPlanned,
    required this.onRecord,
    required this.onAbandon,
  });

  final VoidCallback onOpenSuggestion;
  final VoidCallback onAddStudents;
  final void Function(RunKey key, int step) onResume;
  final void Function(SheetId sheet, Audience audience) onPrepare;
  final void Function(SheetId sheet, Audience audience, String sessionId)
  onLaunch;
  final VoidCallback onOpenPlanned;
  final void Function(GroupId group, DateTime date, SheetId? sheet) onRecord;
  final ValueChanged<RunKey> onAbandon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runs = context.watch<RunningSessionsCubit>().state;
    final upcomingState = context.watch<UpcomingSessionsCubit>().state;
    final upcoming = upcomingState.upcoming;
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: child,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (runs.isNotEmpty)
          gap(
            RunningSessionCard(
              session: runs.first,
              groupName: _groupName(runs.first, upcoming.groupNames),
              onResume: () => onResume(runs.first.key, runs.first.step),
              onAbandon: () => onAbandon(runs.first.key),
            ),
          ),
        for (final other in runs.skip(1))
          gap(
            RunningSessionRow(
              session: other,
              onResume: () => onResume(other.key, other.step),
            ),
          ),
        ...switch (upcomingState.status) {
          UpcomingStatus.loading => const <Widget>[],
          UpcomingStatus.failure => [
            gap(
              _SectionFailed(
                title: l10n.homeNowNext,
                onRetry: () =>
                    unawaited(context.read<UpcomingSessionsCubit>().load()),
              ),
            ),
          ],
          UpcomingStatus.ready => [
            gap(
              upcoming.next == null
                  ? EmptyNextSessionCard(
                      hasClub: upcoming.groupNames.isNotEmpty,
                      onSuggestion: onOpenSuggestion,
                      onAddStudents: onAddStudents,
                    )
                  : NextSessionCard(
                      summary: upcoming.next!,
                      sameDayOthers: upcoming.sameDayOthers,
                      onPrepare: onPrepare,
                      onLaunch: onLaunch,
                      onOpenPlanned: onOpenPlanned,
                    ),
            ),
            if (upcoming.toRecord.isNotEmpty)
              gap(
                ToRecordList(
                  sessions: upcoming.toRecord,
                  onRecord: (summary) {
                    final group = summary.session.groupId;
                    if (group == null) return;
                    onRecord(
                      group,
                      summary.session.date,
                      summary.session.sheetId,
                    );
                  },
                ),
              ),
          ],
        },
      ],
    );
  }

  static String? _groupName(
    RunningSession session,
    Map<GroupId, String> names,
  ) {
    final id = session.plannedGroupId;
    return id == null ? null : names[id];
  }
}

/// « À surveiller », alertes de groupe et « 7 derniers jours ».
class _Follow extends StatelessWidget {
  const _Follow({
    required this.onOpenStudent,
    required this.onOpenStudents,
    required this.onOpenGroup,
  });

  final ValueChanged<StudentId> onOpenStudent;
  final VoidCallback onOpenStudents;
  final ValueChanged<GroupId> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final watched = context.watch<WatchedStudentsCubit>().state;
    final groupAlerts = context.watch<GroupAlertsCubit>().state;
    final week = context.watch<WeekSummaryCubit>().state;
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: child,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (watched.status) {
          WatchedStatus.loading => const SizedBox.shrink(),
          WatchedStatus.failure => gap(
            _SectionFailed(
              title: l10n.homeWatchTitle,
              onRetry: () =>
                  unawaited(context.read<WatchedStudentsCubit>().load()),
            ),
          ),
          WatchedStatus.ready => gap(
            WatchedStudentsCard(
              watchList: watched.watchList,
              onOpenStudent: onOpenStudent,
              onOpenAll: onOpenStudents,
            ),
          ),
        },
        switch (groupAlerts.status) {
          GroupAlertsStatus.loading => const SizedBox.shrink(),
          GroupAlertsStatus.failure => gap(
            _SectionFailed(
              title: l10n.groupAlertsTitle,
              onRetry: () => unawaited(context.read<GroupAlertsCubit>().load()),
            ),
          ),
          GroupAlertsStatus.ready =>
            groupAlerts.alerts.lines.isEmpty
                ? const SizedBox.shrink()
                : gap(
                    GroupAlertsCard(
                      alerts: groupAlerts.alerts,
                      onOpenGroup: onOpenGroup,
                    ),
                  ),
        },
        switch (week.status) {
          WeekStatus.loading => const SizedBox.shrink(),
          WeekStatus.failure => gap(
            _SectionFailed(
              title: l10n.homeWeekTitle,
              onRetry: () => unawaited(context.read<WeekSummaryCubit>().load()),
            ),
          ),
          WeekStatus.ready => gap(WeekSummaryCard(summary: week.summary!)),
        },
      ],
    );
  }
}

/// Une section en échec : son titre, un message calme et « Réessayer ».
class _SectionFailed extends StatelessWidget {
  const _SectionFailed({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: title,
      emphasis: SectionEmphasis.medium,
      child: Row(
        children: [
          Expanded(child: Text(l10n.homeSectionFailed)),
          TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}
