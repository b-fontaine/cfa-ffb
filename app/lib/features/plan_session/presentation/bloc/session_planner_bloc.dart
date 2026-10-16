import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_option.dart';
import 'package:billard_cfa/features/plan_session/domain/delete_session.dart';
import 'package:billard_cfa/features/plan_session/domain/invalid_session_title.dart';
import 'package:billard_cfa/features/plan_session/domain/list_plannable_groups.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sessions.dart';
import 'package:billard_cfa/features/plan_session/domain/list_sheet_options.dart';
import 'package:billard_cfa/features/plan_session/domain/plan_session.dart';
import 'package:billard_cfa/features/plan_session/domain/planned_session_summary.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'session_planner_bloc.freezed.dart';
part 'session_planner_event.dart';
part 'session_planner_state.dart';

@injectable
class SessionPlannerBloc
    extends Bloc<SessionPlannerEvent, SessionPlannerState> {
  SessionPlannerBloc(
    this._planSession,
    this._listSessions,
    this._listOptions,
    this._listGroups,
    this._deleteSession,
  ) : super(const SessionPlannerState()) {
    on<SessionPlannerStarted>(_onStarted);
    on<SessionPlannerSheetSelected>(_onSheetSelected);
    on<SessionPlannerGroupSelected>(_onGroupSelected);
    on<SessionPlannerDateChanged>(_onDateChanged);
    on<SessionPlannerTitleSuggested>(_onTitleSuggested);
    on<SessionPlannerTitleEdited>(_onTitleEdited);
    on<SessionPlannerAudienceChanged>(_onAudienceChanged);
    on<SessionPlannerSessionDeleted>(_onDeleted);
    on<SessionPlannerSessionSubmitted>(_onSubmitted);
  }

  final PlanSession _planSession;
  final ListSessions _listSessions;
  final ListSheetOptions _listOptions;
  final ListPlannableGroups _listGroups;
  final DeleteSession _deleteSession;

  Future<void> _onStarted(
    SessionPlannerStarted event,
    Emitter<SessionPlannerState> emit,
  ) async {
    final sessions = await _listSessions();
    final options = await _listOptions();
    final groups = await _listGroups(today: event.today);
    final loaded = switch (options) {
      Ok(:final value) => value,
      Err() => const <SheetOption>[],
    };
    final preselected = event.sheetId;
    final group = groups.where((g) => g.id == event.groupId).firstOrNull;
    emit(
      state.copyWith(
        sessions: sessions,
        sheetOptions: loaded,
        sheetsUnavailable: options is Err,
        groups: groups,
        date: event.today,
        audience: group?.audience ?? event.audience,
        selectedGroup: group?.id,
        selectedSheet:
            preselected != null && loaded.any((o) => o.id == preselected)
            ? preselected
            : null,
      ),
    );
  }

  void _onSheetSelected(
    SessionPlannerSheetSelected event,
    Emitter<SessionPlannerState> emit,
  ) {
    emit(state.copyWith(selectedSheet: event.sheetId));
  }

  /// Règle : le public suit le groupe choisi ; sans groupe, il reste celui
  /// déjà choisi.
  void _onGroupSelected(
    SessionPlannerGroupSelected event,
    Emitter<SessionPlannerState> emit,
  ) {
    final group = state.groups
        .where((candidate) => candidate.id == event.groupId)
        .firstOrNull;
    emit(
      state.copyWith(
        selectedGroup: group?.id,
        audience: group?.audience ?? state.audience,
        failure: null,
      ),
    );
  }

  void _onDateChanged(
    SessionPlannerDateChanged event,
    Emitter<SessionPlannerState> emit,
  ) {
    emit(state.copyWith(date: event.date, failure: null));
  }

  void _onTitleSuggested(
    SessionPlannerTitleSuggested event,
    Emitter<SessionPlannerState> emit,
  ) {
    // Règle : le titre proposé remplace le titre tant que l'animateur n'y a
    // pas touché (vide, ou encore égal à la proposition précédente).
    final untouched =
        state.title.isEmpty || state.title == state.prefilledTitle;
    if (!untouched) return;
    emit(state.copyWith(title: event.title, prefilledTitle: event.title));
  }

  void _onTitleEdited(
    SessionPlannerTitleEdited event,
    Emitter<SessionPlannerState> emit,
  ) {
    emit(state.copyWith(title: event.title, titleInvalid: false));
  }

  void _onAudienceChanged(
    SessionPlannerAudienceChanged event,
    Emitter<SessionPlannerState> emit,
  ) {
    emit(state.copyWith(audience: event.audience));
  }

  Future<void> _onDeleted(
    SessionPlannerSessionDeleted event,
    Emitter<SessionPlannerState> emit,
  ) async {
    await _deleteSession(event.sessionId);
    emit(state.copyWith(sessions: await _listSessions()));
  }

  Future<void> _onSubmitted(
    SessionPlannerSessionSubmitted event,
    Emitter<SessionPlannerState> emit,
  ) async {
    final date = state.date;
    if (date == null) return;
    try {
      await _planSession(
        title: state.title,
        date: date,
        audience: state.audience,
        sheetId: state.selectedSheet,
        groupId: state.selectedGroup,
      );
      emit(
        state.copyWith(
          sessions: await _listSessions(),
          titleInvalid: false,
          failure: null,
          selectedSheet: null,
          title: '',
          prefilledTitle: null,
          plannedCount: state.plannedCount + 1,
        ),
      );
    } on InvalidSessionTitle {
      emit(state.copyWith(titleInvalid: true));
    } on Failure catch (failure) {
      emit(state.copyWith(failure: failure));
    }
  }
}
