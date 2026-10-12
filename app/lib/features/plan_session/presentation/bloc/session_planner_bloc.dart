import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'session_planner_bloc.freezed.dart';
part 'session_planner_event.dart';
part 'session_planner_state.dart';

@injectable
class SessionPlannerBloc
    extends Bloc<SessionPlannerEvent, SessionPlannerState> {
  SessionPlannerBloc(this._planSession, this._listSessions)
    : super(const SessionPlannerState()) {
    on<SessionPlannerStarted>(_onStarted);
    on<SessionPlannerSessionSubmitted>(_onSubmitted);
  }

  final PlanSession _planSession;
  final ListSessions _listSessions;

  Future<void> _onStarted(
    SessionPlannerStarted event,
    Emitter<SessionPlannerState> emit,
  ) async {
    emit(state.copyWith(sessions: await _listSessions()));
  }

  Future<void> _onSubmitted(
    SessionPlannerSessionSubmitted event,
    Emitter<SessionPlannerState> emit,
  ) async {
    try {
      await _planSession(title: event.title, audience: event.audience);
      emit(
        state.copyWith(sessions: await _listSessions(), titleInvalid: false),
      );
    } on InvalidSessionTitle {
      emit(state.copyWith(titleInvalid: true));
    }
  }
}
