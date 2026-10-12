part of 'exercise_sheet_bloc.dart';

enum ExerciseSheetStatus { loading, ready, failure }

@freezed
abstract class ExerciseSheetState with _$ExerciseSheetState {
  const factory ExerciseSheetState({
    @Default(ExerciseSheetStatus.loading) ExerciseSheetStatus status,
    ExerciseSheet? sheet,
    Failure? failure,
  }) = _ExerciseSheetState;
}
