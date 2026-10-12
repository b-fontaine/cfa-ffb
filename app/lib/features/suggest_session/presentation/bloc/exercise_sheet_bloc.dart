import 'package:billard_cfa/features/suggest_session/domain/exercise_sheet.dart';
import 'package:billard_cfa/features/suggest_session/domain/get_exercise_sheet.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'exercise_sheet_bloc.freezed.dart';
part 'exercise_sheet_event.dart';
part 'exercise_sheet_state.dart';

/// La fiche d'un exercice du catalogue (lien depuis la séance suggérée).
@injectable
class ExerciseSheetBloc extends Bloc<ExerciseSheetEvent, ExerciseSheetState> {
  ExerciseSheetBloc(this._sheet) : super(const ExerciseSheetState()) {
    on<ExerciseSheetStarted>(_onStarted);
  }

  final GetExerciseSheet _sheet;

  Future<void> _onStarted(
    ExerciseSheetStarted event,
    Emitter<ExerciseSheetState> emit,
  ) async {
    emit(const ExerciseSheetState());
    switch (await _sheet(event.exercise)) {
      case Ok(:final value):
        emit(
          ExerciseSheetState(status: ExerciseSheetStatus.ready, sheet: value),
        );
      case Err(:final failure):
        emit(
          ExerciseSheetState(
            status: ExerciseSheetStatus.failure,
            failure: failure,
          ),
        );
    }
  }
}
