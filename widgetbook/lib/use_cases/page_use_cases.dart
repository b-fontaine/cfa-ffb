import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sheet_options.dart';
import 'package:billard_cfa/features/plan_session/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/plan_session_form.dart';
import 'package:billard_cfa/pages/home/presentation/home_page.dart';
import 'package:billard_cfa/pages/not_found/presentation/not_found_page.dart';
import 'package:billard_cfa/pages/session_planner/presentation/session_planner_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/ui/missing_page_view.dart';
import 'package:billard_cfa/widgets/session_list/presentation/session_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/planner_support.dart';
import 'package:widgetbook_workspace/support/preview_world.dart';

@widgetbook.UseCase(name: 'Accueil', type: HomePage, path: '[Pages]')
Widget buildHomePageUseCase(BuildContext context) =>
    HomePage(onOpenPlanner: () {});

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
  const Session(
    id: 'session-1',
    title: 'Bases de la posture',
    audience: Audience.children,
  ),
  Session(
    id: 'session-2',
    title: 'Quantité demi-bille, séance 2/2',
    audience: Audience.adults,
    sheetId: SheetId('demi-bille-2'),
  ),
  Session(
    id: 'session-3',
    title: 'Ancienne séance',
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

@widgetbook.UseCase(name: 'Liste vide', type: SessionList, path: '[Widgets]')
Widget buildSessionListEmptyUseCase(BuildContext context) => SessionList(
  sessions: const [],
  sheetOptions: const [],
  onOpenSheet: (_, _) {},
  onChooseSheet: () {},
  onLaunchSheet: (_, _, _) {},
);

@widgetbook.UseCase(name: 'Liste remplie', type: SessionList, path: '[Widgets]')
Widget buildSessionListFilledUseCase(BuildContext context) => WorldScope(
  builder: (context, world) => LoadedScope<List<SheetOption>>(
    load: (_) => _options()(),
    builder: (context, world, options) => SessionList(
      sessions: _plannedSessions,
      sheetOptions: options,
      onOpenSheet: (_, _) {},
      onChooseSheet: () {},
      onLaunchSheet: (_, _, _) {},
    ),
  ),
);
