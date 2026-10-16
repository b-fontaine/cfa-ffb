import 'package:billard_cfa/features/manage_groups/domain/get_move_options.dart';
import 'package:billard_cfa/features/manage_groups/domain/move_options.dart';
import 'package:billard_cfa/features/manage_groups/domain/move_student.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'move_student_cubit.freezed.dart';

enum MoveStudentStatus { loading, ready, moving, moved, failure }

/// La feuille « Changer de groupe » : ses choix ([options]), l'issue du
/// déplacement ([movedTo], le groupe d'arrivée) ou son refus ([failure]).
@freezed
abstract class MoveStudentState with _$MoveStudentState {
  const factory MoveStudentState({
    @Default(MoveStudentStatus.loading) MoveStudentStatus status,
    MoveOptions? options,
    String? movedTo,
    Failure? failure,
  }) = _MoveStudentState;
}

/// Déplacer un élève dans un autre groupe de son public (ADR 0019). La date
/// d'effet proposée est le jour courant.
@injectable
class MoveStudentCubit extends Cubit<MoveStudentState> {
  MoveStudentCubit(this._options, this._move, this._clock)
    : super(const MoveStudentState());

  final GetMoveOptions _options;
  final MoveStudent _move;
  final Clock _clock;

  DateTime get today => _clock.today();

  Future<void> load(StudentId studentId) async {
    emit(const MoveStudentState());
    switch (await _options(studentId: studentId, today: _clock.today())) {
      case Ok(:final value):
        emit(MoveStudentState(status: MoveStudentStatus.ready, options: value));
      case Err(:final failure):
        emit(
          MoveStudentState(status: MoveStudentStatus.failure, failure: failure),
        );
    }
  }

  Future<void> submit({
    required StudentId studentId,
    required GroupId toGroupId,
    required DateTime on,
  }) async {
    final options = state.options;
    emit(MoveStudentState(status: MoveStudentStatus.moving, options: options));
    switch (await _move(studentId: studentId, toGroupId: toGroupId, on: on)) {
      case Ok(:final value):
        emit(
          MoveStudentState(
            status: MoveStudentStatus.moved,
            options: options,
            movedTo: value.name,
          ),
        );
      case Err(:final failure):
        emit(
          MoveStudentState(
            status: MoveStudentStatus.ready,
            options: options,
            failure: failure,
          ),
        );
    }
  }
}
