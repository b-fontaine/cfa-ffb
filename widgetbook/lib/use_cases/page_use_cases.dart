import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/features/plan_session/presentation/ui/plan_session_form.dart';
import 'package:billard_cfa/pages/home/presentation/home_page.dart';
import 'package:billard_cfa/pages/not_found/presentation/not_found_page.dart';
import 'package:billard_cfa/pages/session_planner/presentation/session_planner_page.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/widgets/session_list/presentation/session_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:widgetbook_workspace/support/planner_support.dart';

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
  name: 'Planification vide',
  type: SessionPlannerPage,
  path: '[Pages]',
)
Widget buildPlannerEmptyUseCase(BuildContext context) =>
    BlocProvider<SessionPlannerBloc>(
      create: (_) => buildPlannerBloc(),
      child: const SessionPlannerPage(),
    );

@widgetbook.UseCase(
  name: 'Planification avec séances',
  type: SessionPlannerPage,
  path: '[Pages]',
)
Widget buildPlannerFilledUseCase(BuildContext context) =>
    BlocProvider<SessionPlannerBloc>(
      create: (_) => buildPlannerBloc([
        ('Bases de la posture', Audience.children),
        ('Jeu de position', Audience.adults),
      ]),
      child: const SessionPlannerPage(),
    );

@widgetbook.UseCase(
  name: 'Formulaire',
  type: PlanSessionForm,
  path: '[Features]',
)
Widget buildPlanSessionFormUseCase(BuildContext context) =>
    BlocProvider<SessionPlannerBloc>(
      create: (_) => buildPlannerBloc(),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: PlanSessionForm(),
      ),
    );

@widgetbook.UseCase(name: 'Liste vide', type: SessionList, path: '[Widgets]')
Widget buildSessionListEmptyUseCase(BuildContext context) =>
    const SessionList(sessions: []);

@widgetbook.UseCase(name: 'Liste remplie', type: SessionList, path: '[Widgets]')
Widget buildSessionListFilledUseCase(BuildContext context) => const SessionList(
  sessions: [
    Session(
      id: 'session-1',
      title: 'Bases de la posture',
      audience: Audience.children,
    ),
    Session(
      id: 'session-2',
      title: 'Jeu de position',
      audience: Audience.adults,
    ),
  ],
);
