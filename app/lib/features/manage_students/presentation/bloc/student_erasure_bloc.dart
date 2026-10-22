import 'package:billard_cfa/features/manage_students/domain/student_erasure.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_runner.dart';
import 'package:billard_cfa/shared/lib/operations/student_purge.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'student_erasure_bloc.freezed.dart';
part 'student_erasure_event.dart';
part 'student_erasure_state.dart';

/// Effacement physique d'un élève (la confirmation est demandée par l'écran).
/// Sur l'appareil, c'est instantané ; dans un club synchronisé, l'effacement se
/// fait par lots reprenables : l'avancement est montré, l'arrêt se prend entre
/// deux lots, et un effacement commencé se **reprend** à l'ouverture de la
/// fiche (ADR 0024, décision 19 ; FB8).
@injectable
class StudentErasureBloc
    extends Bloc<StudentErasureEvent, StudentErasureState> {
  StudentErasureBloc(this._erasure) : super(const StudentErasureState()) {
    on<StudentErasureInspected>(_onInspected);
    on<StudentErasureRequested>(_onRequested);
    on<StudentErasureStopRequested>((event, emit) => _stop = true);
  }

  final StudentErasure _erasure;
  bool _stop = false;

  Future<void> _onInspected(
    StudentErasureInspected event,
    Emitter<StudentErasureState> emit,
  ) async {
    switch (await _erasure.inspect(event.studentId)) {
      case Ok(:final value):
        emit(
          StudentErasureState(
            status: StudentErasureStatus.ready,
            preview: value.preview,
            inProgress: value.inProgress,
            synchronized: value.synchronized,
          ),
        );
      case Err(:final failure):
        emit(
          StudentErasureState(
            status: StudentErasureStatus.failure,
            failure: failure,
          ),
        );
    }
  }

  Future<void> _onRequested(
    StudentErasureRequested event,
    Emitter<StudentErasureState> emit,
  ) async {
    _stop = false;
    final before = state;
    emit(
      before.copyWith(
        status: StudentErasureStatus.working,
        done: 0,
        total: 0,
        failure: null,
      ),
    );
    var done = 0;
    var total = 0;
    final result = await _erasure.erase(
      event.studentId,
      shouldStop: () => _stop,
      onProgress: (d, t) {
        done = d;
        total = t;
        if (!emit.isDone) {
          emit(state.copyWith(done: d, total: t));
        }
      },
    );
    if (emit.isDone) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: switch (value.status) {
              OperationRunStatus.completed => StudentErasureStatus.erased,
              OperationRunStatus.cancelled => StudentErasureStatus.stopped,
              OperationRunStatus.interrupted =>
                StudentErasureStatus.interrupted,
              OperationRunStatus.paused => StudentErasureStatus.paused,
              OperationRunStatus.failed => StudentErasureStatus.failure,
            },
            inProgress: value.status != OperationRunStatus.completed,
            done: value.doneLots == 0 ? done : value.doneLots,
            total: value.totalLots == 0 ? total : value.totalLots,
            failure: value.failure,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: StudentErasureStatus.failure,
            failure: failure,
          ),
        );
    }
  }
}
