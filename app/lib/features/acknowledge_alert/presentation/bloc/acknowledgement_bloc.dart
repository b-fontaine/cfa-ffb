import 'package:billard_cfa/features/acknowledge_alert/domain/acknowledge_alert.dart';
import 'package:billard_cfa/features/acknowledge_alert/domain/restore_alert.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'acknowledgement_bloc.freezed.dart';
part 'acknowledgement_event.dart';
part 'acknowledgement_state.dart';

/// Acquittement d'une alerte depuis la fiche d'un élève : « Vu » et
/// « Rétablir » (ADR 0013).
@injectable
class AcknowledgementBloc
    extends Bloc<AcknowledgementEvent, AcknowledgementState> {
  AcknowledgementBloc(this._acknowledge, this._restore, this._clock)
    : super(const AcknowledgementState()) {
    on<AcknowledgementAcknowledgeRequested>(_onAcknowledgeRequested);
    on<AcknowledgementRestoreRequested>(_onRestoreRequested);
  }

  final AcknowledgeAlert _acknowledge;
  final RestoreAlert _restore;
  final Clock _clock;

  Future<void> _onAcknowledgeRequested(
    AcknowledgementAcknowledgeRequested event,
    Emitter<AcknowledgementState> emit,
  ) async {
    emit(_working(AcknowledgementAction.acknowledge, event.exercise));
    final result = await _acknowledge(
      studentId: event.studentId,
      exercise: event.exercise,
      today: _clock.today(),
    );
    _conclude(emit, AcknowledgementAction.acknowledge, event.exercise, result);
  }

  Future<void> _onRestoreRequested(
    AcknowledgementRestoreRequested event,
    Emitter<AcknowledgementState> emit,
  ) async {
    emit(_working(AcknowledgementAction.restore, event.exercise));
    final result = await _restore(
      studentId: event.studentId,
      exercise: event.exercise,
    );
    _conclude(emit, AcknowledgementAction.restore, event.exercise, result);
  }

  AcknowledgementState _working(
    AcknowledgementAction action,
    ExerciseRef exercise,
  ) => AcknowledgementState(
    status: AcknowledgementStatus.working,
    action: action,
    exercise: exercise,
  );

  void _conclude(
    Emitter<AcknowledgementState> emit,
    AcknowledgementAction action,
    ExerciseRef exercise,
    Result<Object?> result,
  ) {
    emit(switch (result) {
      Ok() => AcknowledgementState(
        status: AcknowledgementStatus.done,
        action: action,
        exercise: exercise,
      ),
      Err(:final failure) => AcknowledgementState(
        status: AcknowledgementStatus.refused,
        action: action,
        exercise: exercise,
        failure: failure,
      ),
    });
  }
}
