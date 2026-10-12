import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/get_exercise_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/session_plan.dart';
import 'package:billard_cfa/features/suggest_session/domain/suggest_session.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'suggested_session_bloc.freezed.dart';
part 'suggested_session_event.dart';
part 'suggested_session_state.dart';

/// La séance suggérée pour un groupe, avec les fiches de ses exercices.
@injectable
class SuggestedSessionBloc
    extends Bloc<SuggestedSessionEvent, SuggestedSessionState> {
  SuggestedSessionBloc(this._suggest, this._sheet)
    : super(const SuggestedSessionState()) {
    on<SuggestedSessionRequested>(_onRequested);
  }

  final SuggestSession _suggest;
  final GetExerciseSheet _sheet;

  Future<void> _onRequested(
    SuggestedSessionRequested event,
    Emitter<SuggestedSessionState> emit,
  ) async {
    emit(const SuggestedSessionState(status: SuggestedStatus.loading));
    final result = await _suggest(
      groupId: event.groupId,
      expectedStudents: event.expectedStudents,
    );
    switch (result) {
      case Err(:final failure):
        emit(
          SuggestedSessionState(
            status: SuggestedStatus.failure,
            failure: failure,
          ),
        );
      case Ok(:final value):
        final exercises = <ExerciseSheet>[];
        for (final exercise in value.exercises) {
          switch (await _sheet(exercise)) {
            case Ok(value: final sheet):
              exercises.add(sheet);
            case Err(:final failure):
              emit(
                SuggestedSessionState(
                  status: SuggestedStatus.failure,
                  failure: failure,
                ),
              );
              return;
          }
        }
        ExerciseSheet? recall;
        final recallExercise = value.recallExercise;
        if (recallExercise != null) {
          switch (await _sheet(recallExercise)) {
            case Ok(value: final sheet):
              recall = sheet;
            case Err(:final failure):
              emit(
                SuggestedSessionState(
                  status: SuggestedStatus.failure,
                  failure: failure,
                ),
              );
              return;
          }
        }
        emit(
          SuggestedSessionState(
            status: SuggestedStatus.ready,
            groupId: event.groupId,
            plan: value,
            exercises: exercises,
            recall: recall,
          ),
        );
    }
  }
}
