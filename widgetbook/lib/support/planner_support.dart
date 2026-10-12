import 'package:billard_cfa/entities/session/data/in_memory_session_repository.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/features/plan_session/presentation/bloc/session_planner_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';

/// Construit un Bloc de planification réel, adossé au repository en mémoire,
/// et y planifie [sessions] (titre, public).
SessionPlannerBloc buildPlannerBloc([
  List<(String, Audience)> sessions = const [],
]) {
  final repository = InMemorySessionRepository();
  final bloc = SessionPlannerBloc(
    PlanSession(repository, SequentialIdGenerator()),
    ListSessions(repository),
  )..add(const SessionPlannerEvent.started());
  for (final (title, audience) in sessions) {
    bloc.add(
      SessionPlannerEvent.sessionSubmitted(title: title, audience: audience),
    );
  }
  return bloc;
}
