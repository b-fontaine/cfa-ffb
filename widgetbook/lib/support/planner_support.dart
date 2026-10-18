import 'dart:async';

import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/season/data/in_memory_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_record/data/in_memory_session_record_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/delete_session.dart';
import 'package:billard_cfa/features/plan_session/domain/list_plannable_groups.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sheet_options.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';

/// « Aujourd'hui » des cas de planification.
final plannerToday = DateTime(2026, 10, 12);

/// Groupes de la saison 2026-2027 proposés par les cas de planification.
final plannerGroups = [
  Group(
    id: const GroupId('g1'),
    seasonId: const SeasonId('season'),
    name: 'Jeunes',
    audience: Audience.children,
  ),
  Group(
    id: const GroupId('g2'),
    seasonId: const SeasonId('season'),
    name: 'Adultes du mardi',
    audience: Audience.adults,
  ),
];

/// Construit un Bloc de planification réel, adossé aux dépôts en mémoire
/// (déjà garnis de [sessions] et de [plannerGroups]) et au catalogue de
/// séances [options].
///
/// [preselected] et [group] reproduisent le lien profond du détail d'une
/// séance.
SessionPlannerBloc buildPlannerBloc(
  ListSheetOptions options, {
  List<Session> sessions = const [],
  SheetId? preselected,
  GroupId? group,
}) {
  final repository = InMemorySessionRepository();
  final groups = InMemoryGroupRepository();
  final seasons = InMemorySeasonRepository();
  final records = InMemorySessionRecordRepository();
  // L'écriture en mémoire est synchrone jusqu'à son premier `await`.
  unawaited(
    seasons.save(
      Season(
        id: const SeasonId('season'),
        label: '2026-2027',
        startDate: DateTime(2026, 9),
        endDate: DateTime(2027, 6, 30),
      ),
    ),
  );
  for (final group in plannerGroups) {
    unawaited(groups.save(group));
  }
  for (final session in sessions) {
    unawaited(repository.add(session));
  }
  return SessionPlannerBloc(
    PlanSession(repository, groups, seasons, SequentialIdGenerator()),
    ListSessions(repository, groups, records),
    options,
    ListPlannableGroups(groups, seasons),
    DeleteSession(repository),
  )..add(
    SessionPlannerEvent.started(
      today: plannerToday,
      sheetId: preselected,
      groupId: group,
    ),
  );
}
