import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/record_results/domain/open_or_resume_session.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'open_session_bloc.freezed.dart';
part 'open_session_event.dart';
part 'open_session_state.dart';

/// Ouverture (ou reprise) de la séance d'un groupe pour saisir les résultats.
@injectable
class OpenSessionBloc extends Bloc<OpenSessionEvent, OpenSessionState> {
  OpenSessionBloc(this._open) : super(const OpenSessionState()) {
    on<OpenSessionRequested>(_onRequested);
  }

  final OpenOrResumeSession _open;

  Future<void> _onRequested(
    OpenSessionRequested event,
    Emitter<OpenSessionState> emit,
  ) async {
    emit(const OpenSessionState(status: OpenSessionStatus.opening));
    final result = await _open(
      groupId: event.groupId,
      date: event.date,
      present: event.present,
      mainBlockId: event.mainBlockId,
      recallBlockId: event.recallBlockId,
    );
    switch (result) {
      case Ok(:final value):
        emit(
          OpenSessionState(status: OpenSessionStatus.opened, session: value),
        );
      case Err(:final failure):
        emit(
          OpenSessionState(status: OpenSessionStatus.failure, failure: failure),
        );
    }
  }
}
