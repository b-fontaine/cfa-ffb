import 'dart:async';

import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sheet_options.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/plan_next_session_cubit.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/upcoming_sessions_cubit.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/plan_session_form.dart';
import 'package:billard_cfa/features/review_session/presentation/bloc/session_review_bloc.dart';
import 'package:billard_cfa/features/run_sheet/presentation/bloc/running_sessions_cubit.dart';
import 'package:billard_cfa/features/suggest_session/presentation/bloc/next_sheet_cubit.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/watched_students_cubit.dart';
import 'package:billard_cfa/features/track_progress/presentation/bloc/week_summary_cubit.dart';
import 'package:billard_cfa/pages/home/presentation/home_page.dart';
import 'package:billard_cfa/pages/not_found/presentation/not_found_page.dart';
import 'package:billard_cfa/pages/session_planner/presentation/session_planner_page.dart';
import 'package:billard_cfa/pages/session_review/presentation/session_review_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:billard_cfa/widgets/session_list/presentation/session_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/planner_support.dart';
import 'package:widgetbook_workspace/support/preview_world.dart';

/// Démarre [start] sur [cubit] sans attendre : le cubit publie ses états.
T _loaded<T>(T cubit, Future<void> Function(T cubit) start) {
  unawaited(start(cubit));
  return cubit;
}

@widgetbook.UseCase(name: 'Accueil', type: HomePage, path: '[Pages]')
Widget buildHomePageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => getIt<RunningSessionsCubit>()..refresh()),
      BlocProvider(
        create: (_) =>
            _loaded(getIt<UpcomingSessionsCubit>(), (cubit) => cubit.load()),
      ),
      BlocProvider(
        create: (_) =>
            _loaded(getIt<WatchedStudentsCubit>(), (cubit) => cubit.load()),
      ),
      BlocProvider(
        create: (_) =>
            _loaded(getIt<WeekSummaryCubit>(), (cubit) => cubit.load()),
      ),
    ],
    child: HomePage(
      today: () => world.today,
      onOpenPlanner: () {},
      onOpenSuggestion: () {},
      onAddStudents: () {},
      onOpenStudents: () {},
      onOpenStudent: (_) {},
      onResume: (_, _) {},
      onPrepare: (_, _) {},
      onLaunch: (_, _, _) {},
      onOpenPlanned: () {},
      onRecord: (_, _, _) {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Bilan de séance',
  type: SessionReviewPage,
  path: '[Pages]',
)
Widget buildSessionReviewPageUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            getIt<SessionReviewBloc>()
              ..add(SessionReviewEvent.started(world.sessionId)),
      ),
      BlocProvider(create: (_) => getIt<NextSheetCubit>()),
      BlocProvider(create: (_) => getIt<PlanNextSessionCubit>()),
    ],
    child: SessionReviewPage(
      today: () => world.today,
      onBackToday: () {},
      onOpenRecord: (_) {},
      onEnterResults: (_) {},
      onOpenStudent: (_) {},
      onOpenPlanner: (_, _) {},
      onOpenPlanned: () {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Adresse introuvable',
  type: NotFoundPage,
  path: '[Pages]',
)
Widget buildNotFoundPageUseCase(BuildContext context) =>
    NotFoundPage(onHome: () {});

@widgetbook.UseCase(
  name: 'Page introuvable',
  type: MissingPageView,
  path: '[Design system]/Composants',
)
Widget buildMissingPageViewUseCase(BuildContext context) =>
    MissingPageView(onHome: () {});

/// Séances du catalogue lues par le cas d'usage réel, sur les assets.
ListSheetOptions _options() =>
    ListSheetOptions(getIt<SessionSheetRepository>());

final _plannedSessions = [
  Session(
    id: 'session-1',
    title: 'Bases de la posture',
    date: DateTime(2026, 10, 12),
    audience: Audience.children,
  ),
  Session(
    id: 'session-2',
    title: 'Quantité demi-bille, séance 2/2',
    date: DateTime(2026, 10, 19),
    audience: Audience.adults,
    sheetId: SheetId('demi-bille-2'),
  ),
  Session(
    id: 'session-3',
    title: 'Ancienne séance',
    date: DateTime(2026, 10, 26),
    audience: Audience.children,
    sheetId: SheetId('inconnue-9'),
  ),
];

@widgetbook.UseCase(
  name: 'Planification vide',
  type: SessionPlannerPage,
  path: '[Pages]',
)
Widget buildPlannerEmptyUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider<SessionPlannerBloc>(
    create: (_) => buildPlannerBloc(_options()),
    child: SessionPlannerPage(
      onOpenSheet: (_, _) {},
      onChooseSheet: () {},
      onLaunchSheet: (_, _, _) {},
      onRecord: (_, _, _) {},
      onOpenRecord: (_) {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Planification avec séances',
  type: SessionPlannerPage,
  path: '[Pages]',
)
Widget buildPlannerFilledUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider<SessionPlannerBloc>(
    create: (_) => buildPlannerBloc(_options(), sessions: _plannedSessions),
    child: SessionPlannerPage(
      onOpenSheet: (_, _) {},
      onChooseSheet: () {},
      onLaunchSheet: (_, _, _) {},
      onRecord: (_, _, _) {},
      onOpenRecord: (_) {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Planification depuis une séance du catalogue',
  type: SessionPlannerPage,
  path: '[Pages]',
)
Widget buildPlannerFromSheetUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider<SessionPlannerBloc>(
    create: (_) => buildPlannerBloc(
      _options(),
      preselected: SheetId('demi-bille-2'),
      audience: Audience.adults,
    ),
    child: SessionPlannerPage(
      onOpenSheet: (_, _) {},
      onChooseSheet: () {},
      onLaunchSheet: (_, _, _) {},
      onRecord: (_, _, _) {},
      onOpenRecord: (_) {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Formulaire',
  type: PlanSessionForm,
  path: '[Features]',
)
Widget buildPlanSessionFormUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => BlocProvider<SessionPlannerBloc>(
    create: (_) => buildPlannerBloc(_options()),
    child: const Padding(padding: EdgeInsets.all(16), child: PlanSessionForm()),
  ),
);

/// Résumés des séances planifiées : la première pour le groupe « Jeunes »,
/// la deuxième déjà saisie, la troisième pour un groupe disparu.
final _summaries = [
  PlannedSessionSummary(
    session: _plannedSessions[0].copyWith(groupId: const GroupId('g1')),
    group: plannerGroups.first,
  ),
  PlannedSessionSummary(
    session: _plannedSessions[1].copyWith(groupId: const GroupId('g2')),
    group: plannerGroups.last,
    recordId: const SessionId('x1'),
  ),
  PlannedSessionSummary(
    session: _plannedSessions[2].copyWith(groupId: const GroupId('gone')),
  ),
];

@widgetbook.UseCase(name: 'Liste vide', type: SessionList, path: '[Widgets]')
Widget buildSessionListEmptyUseCase(BuildContext context) => SessionList(
  sessions: const [],
  sheetOptions: const [],
  onOpenSheet: (_, _) {},
  onChooseSheet: () {},
  onLaunchSheet: (_, _, _) {},
  onRecord: (_, _, _) {},
  onOpenRecord: (_) {},
);

@widgetbook.UseCase(name: 'Liste remplie', type: SessionList, path: '[Widgets]')
Widget buildSessionListFilledUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => LoadedScope<List<SheetOption>>(
    load: (_) => _options()(),
    builder: (context, world, options) => SessionList(
      sessions: [
        for (final session in _plannedSessions)
          PlannedSessionSummary(session: session),
      ],
      sheetOptions: options,
      onOpenSheet: (_, _) {},
      onChooseSheet: () {},
      onLaunchSheet: (_, _, _) {},
      onRecord: (_, _, _) {},
      onOpenRecord: (_) {},
    ),
  ),
);

@widgetbook.UseCase(
  name: 'Liste avec groupes et saisies',
  type: SessionList,
  path: '[Widgets]',
)
Widget buildSessionListGroupsUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => LoadedScope<List<SheetOption>>(
    load: (_) => _options()(),
    builder: (context, world, options) => SessionList(
      sessions: _summaries,
      sheetOptions: options,
      onOpenSheet: (_, _) {},
      onChooseSheet: () {},
      onLaunchSheet: (_, _, _) {},
      onRecord: (_, _, _) {},
      onOpenRecord: (_) {},
      onDelete: (_) {},
    ),
  ),
);
