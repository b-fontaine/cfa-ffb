import 'package:billard_cfa/features/record_results/domain/list_recorded_sessions.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_session_summary.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'recorded_sessions_bloc.freezed.dart';
part 'recorded_sessions_event.dart';
part 'recorded_sessions_state.dart';

/// Historique des séances saisies (liste, de la plus récente à la plus
/// ancienne).
@injectable
class RecordedSessionsBloc
    extends Bloc<RecordedSessionsEvent, RecordedSessionsState> {
  RecordedSessionsBloc(this._list) : super(const RecordedSessionsState()) {
    on<RecordedSessionsStarted>(_load);
    on<RecordedSessionsRefreshed>(_load);
  }

  final ListRecordedSessions _list;

  Future<void> _load(
    RecordedSessionsEvent event,
    Emitter<RecordedSessionsState> emit,
  ) async {
    emit(state.copyWith(status: RecordedSessionsStatus.loading));
    switch (await _list()) {
      case Ok(:final value):
        emit(
          RecordedSessionsState(
            status: RecordedSessionsStatus.ready,
            sessions: value,
          ),
        );
      case Err(:final failure):
        emit(
          RecordedSessionsState(
            status: RecordedSessionsStatus.failure,
            failure: failure,
          ),
        );
    }
  }
}
