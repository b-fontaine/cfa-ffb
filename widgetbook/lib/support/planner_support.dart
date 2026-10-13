import 'dart:async';

import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/delete_session.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sheet_options.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

/// Construit un Bloc de planification réel, adossé au repository en mémoire
/// (déjà garni de [sessions]) et au catalogue de séances [options].
///
/// [preselected] et [audience] reproduisent le lien profond du détail d'une
/// séance.
SessionPlannerBloc buildPlannerBloc(
  ListSheetOptions options, {
  List<Session> sessions = const [],
  SheetId? preselected,
  Audience audience = Audience.children,
}) {
  final repository = InMemorySessionRepository();
  for (final session in sessions) {
    // L'écriture en mémoire est synchrone jusqu'à son premier `await`.
    unawaited(repository.add(session));
  }
  return SessionPlannerBloc(
    PlanSession(repository, SequentialIdGenerator()),
    ListSessions(repository),
    options,
    DeleteSession(repository),
  )..add(SessionPlannerEvent.started(sheetId: preselected, audience: audience));
}
